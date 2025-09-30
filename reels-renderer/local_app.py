# local_app.py — Fast local reel renderer (no GCS/Firestore)
# ----------------------------------------------------------
# - Reads files from disk (absolute paths, file://, or http(s))
# - Writes final MP4 to your Desktop
# - Supports fitMode: "cover" | "contain" | "native"
#     * cover  -> fill 1080x1920 (crop overflow)
#     * contain-> letterbox/pillarbox to 1080x1920 (no crop)
#     * native -> (single video only) keep original size, no resize/crop
#
# Run:
#   python3 -m venv .venv && source .venv/bin/activate
#   python -m pip install fastapi uvicorn "moviepy<2" imageio-ffmpeg imageio numpy pillow
#   .venv/bin/uvicorn local_app:app --reload
#
# Test (single video, native):
#   curl -X POST http://127.0.0.1:8000/render-local -H 'Content-Type: application/json' -d '{
#     "gatheringId":"single","targetSeconds":10,"crossfade":0.0,"fitMode":"native",
#     "video":{"width":1080,"height":1920,"fps":30},
#     "clips":[{"gcsPath":"/Users/sa/Desktop/nisaf.mov","maxLen":10}]
#   }'

import os, sys, time, json, tempfile, subprocess, shutil, urllib.request
from typing import List, Optional, Tuple, Literal

# --- Pillow 10+ back-compat for MoviePy 1.x (ANTIALIAS removed in Pillow>=10) ---
try:
    from PIL import Image as _PILImage  # noqa
    if not hasattr(_PILImage, "ANTIALIAS") and hasattr(_PILImage, "Resampling"):
        _PILImage.ANTIALIAS = _PILImage.Resampling.LANCZOS
except Exception:
    pass

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# --------------------
# App & basic logging
# --------------------
import logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    stream=sys.stdout,
    force=True,
)
log = logging.getLogger("local_renderer")

app = FastAPI(title="Local Reel Renderer", version="1.1")

# --------------
# Pydantic I/O
# --------------
class KenBurns(BaseModel):
    zoom: float = 0.07

class ClipIn(BaseModel):
    gcsPath: str
    type: Optional[Literal["image","video"]] = None   # if omitted we auto-detect by ext
    maxLen: Optional[float] = None                    # per-clip cap for videos (sec)

class VideoSpec(BaseModel):
    width: int = 1080
    height: int = 1920
    fps: int = 30

class RenderRequest(BaseModel):
    gatheringId: str = "local"
    targetSeconds: Optional[float] = 60.0
    crossfade: float = 0.5
    clips: List[ClipIn]
    kenBurns: Optional[KenBurns] = KenBurns()
    video: Optional[VideoSpec] = VideoSpec()
    fitMode: str = "cover"          # "cover" | "contain" | "native"

class RenderResponse(BaseModel):
    output: str
    duration: float

# --------------------
# Helpers (ffprobe / fit)
# --------------------
def _is_video_ext(path: str) -> bool:
    ext = os.path.splitext(path.lower())[1]
    return ext in {".mp4", ".mov", ".m4v", ".avi", ".mkv", ".webm"}

def _is_image_ext(path: str) -> bool:
    ext = os.path.splitext(path.lower())[1]
    return ext in {".jpg", ".jpeg", ".png", ".bmp", ".gif"}


def _snap_nocrop(v, w, h, tol=0.02):
    """
    If v's AR is within `tol` of the target AR, scale-to-height and
    crop/pad a *few* pixels to land exactly on (w,h) with no visible bars.
    Otherwise return None (caller should 'contain').
    """
    target_ar = w / h
    ar = v.w / v.h
    if abs(ar - target_ar) < tol:
        scale = h / v.h
        v2 = v.resize(scale)
        # tiny mismatch fix
        from moviepy.video.fx.all import crop
        if v2.w > w + 1:
            v2 = crop(v2, width=w, height=h, x_center=v2.w/2, y_center=v2.h/2)
        elif v2.w < w - 1:
            from moviepy.video.compositing.CompositeVideoClip import CompositeVideoClip
            v2 = CompositeVideoClip([v2.set_position("center")], size=(w, h), bg_color=(0,0,0))
        return v2
    return None


def _run(cmd):
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

def _ffprobe_rotation(path: str) -> int:
    p = _run([
        "ffprobe","-v","error","-select_streams","v:0",
        "-show_entries","stream=side_data_list:stream_tags=rotate",
        "-of","json", path
    ])
    if p.returncode != 0 or not p.stdout:
        return 0
    import json as _json
    j = _json.loads(p.stdout)
    s = (j.get("streams") or [{}])[0]
    rot = int((s.get("tags") or {}).get("rotate", 0) or 0)
    if rot == 0:
        for it in (s.get("side_data_list") or []):
            if it.get("rotation") is not None:
                try:
                    rot = int(round(float(it["rotation"])))
                    break
                except Exception:
                    pass
    return rot % 360

def _strip_rotation_inplace(path: str) -> None:
    tmp = path + ".norot.mp4"
    # quick copy attempt
    p = _run([
        "ffmpeg","-y","-loglevel","error","-i", path,
        "-map","0","-map_metadata","-1",
        "-metadata:s:v:0","rotate=0",
        "-metadata","rotate=0",
        "-c","copy","-movflags","+faststart", tmp
    ])
    # if any rotation survives, re-encode (fast, quality-safe)
    if p.returncode != 0 or _ffprobe_rotation(tmp) != 0:
        p2 = _run([
            "ffmpeg","-y","-loglevel","error","-i", path,
            "-map","0","-map_metadata","-1",
            "-metadata:s:v:0","rotate=0",
            "-metadata","rotate=0",
            "-vf","scale=iw:ih,setsar=1",
            "-c:v","libx264","-preset","veryfast","-crf","18",
            "-c:a","copy","-movflags","+faststart", tmp
        ])
        if p2.returncode != 0:
            raise RuntimeError("ffmpeg re-encode to strip rotation failed")
    os.replace(tmp, path)




# def _probe_geom(path: str) -> Tuple[int, int, int]:
#     """Return (rotate_deg, sar_num, sar_den). Defaults to (0,1,1)."""
#     cmd = [
#         "ffprobe","-v","error","-select_streams","v:0",
#         "-show_entries","stream=sample_aspect_ratio:stream_tags=rotate",
#         "-of","json", path
#     ]
#     try:
#         p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
#         rot, sn, sd = 0, 1, 1
#         if p.returncode == 0 and p.stdout:
#             j = json.loads(p.stdout)
#             if j.get("streams"):
#                 s = j["streams"][0]
#                 rot = int(s.get("tags",{}).get("rotate",0) or 0)
#                 sar = s.get("sample_aspect_ratio", "1:1")
#                 try:
#                     sn, sd = [int(x) for x in sar.split(":")]
#                 except Exception:
#                     pass
#         return rot % 360, max(sn,1), max(sd,1)
#     except Exception as e:
#         log.warning(f"ffprobe failed on {path}: {e}")
#         return 0, 1, 1

def _probe_geom(path: str):
    """
    Return (rotate_deg, sar_num, sar_den). Defaults to (0,1,1).

    - rotation: prefer stream.tags.rotate; if absent, use side_data_list 'Display Matrix' rotation
    - sar: sample_aspect_ratio (num:den)
    """
    cmd = [
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries",
        "stream=width,height,sample_aspect_ratio,display_aspect_ratio:stream_tags=rotate:side_data_list",
        "-of", "json", path
    ]
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    rot, sn, sd = 0, 1, 1
    if p.returncode == 0 and p.stdout:
        try:
            j = json.loads(p.stdout)
            if j.get("streams"):
                s = j["streams"][0]

                # --- sample aspect ratio ---
                sar = s.get("sample_aspect_ratio") or "1:1"
                try:
                    sn, sd = [int(x) for x in sar.split(":")]
                except Exception:
                    sn, sd = 1, 1

                # --- rotation from tags.rotate ---
                rot = int(s.get("tags", {}).get("rotate", 0) or 0)

                # --- fallback: rotation from side_data_list 'Display Matrix' ---
                if rot == 0:
                    for sd_item in s.get("side_data_list", []) or []:
                        # newer ffmpeg often provides a numeric 'rotation'
                        if sd_item.get("rotation") is not None:
                            try:
                                rot = int(round(float(sd_item["rotation"])))
                                break
                            except Exception:
                                pass
                        # some builds only provide side_data_type and displaymatrix text; skip complex math here

        except Exception:
            pass
    return rot % 360, max(sn, 1), max(sd, 1)






def _download_or_copy_to_tmp(src: str) -> str:
    """Accept file://, absolute/relative, or http(s) and return a local temp path."""
    if src.startswith("file://"):
        src = src.replace("file://", "", 1)
    if src.startswith(("http://","https://")):
        fd, tmp = tempfile.mkstemp(prefix="media_", suffix=os.path.splitext(src)[1] or ".bin")
        os.close(fd)
        urllib.request.urlretrieve(src, tmp)
        return tmp
    src_abs = os.path.abspath(src)
    if not os.path.exists(src_abs):
        raise FileNotFoundError(f"Local path not found: {src_abs}")
    fd, tmp = tempfile.mkstemp(prefix="media_", suffix=os.path.splitext(src_abs)[1])
    os.close(fd)
    shutil.copyfile(src_abs, tmp)
    return tmp

# Fit helpers (no stretch)
# def fit_clip_cover(clip, w: int, h: int):
#     from moviepy.video.compositing.CompositeVideoClip import CompositeVideoClip
#     scale = max(w / clip.w, h / clip.h)
#     clip = clip.resize(scale)
#     return CompositeVideoClip([clip.set_position("center")], size=(w, h))

# def fit_clip_contain(clip, w: int, h: int, bg_color=(0,0,0)):
#     from moviepy.video.compositing.CompositeVideoClip import CompositeVideoClip
#     scale = min(w / clip.w, h / clip.h)
#     clip = clip.resize(scale)
#     return CompositeVideoClip([clip.set_position("center")], size=(w, h), bg_color=bg_color)

def fit_clip_cover(clip, w: int, h: int):
    from moviepy.video.compositing.CompositeVideoClip import CompositeVideoClip
    scale = max(w / clip.w, h / clip.h)
    log.info(f"[fit_cover] in={clip.w}x{clip.h} target={w}x{h} scale={scale:.4f}")
    clip = clip.resize(scale)
    out = CompositeVideoClip([clip.set_position("center")], size=(w, h))
    log.info(f"[fit_cover] out={out.w}x{out.h}")
    return out

def fit_clip_contain(clip, w: int, h: int, bg_color=(0,0,0)):
    from moviepy.video.compositing.CompositeVideoClip import CompositeVideoClip
    scale = min(w / clip.w, h / clip.h)
    log.info(f"[fit_contain] in={clip.w}x{clip.h} target={w}x{h} scale={scale:.4f}")
    clip = clip.resize(scale)
    out = CompositeVideoClip([clip.set_position("center")], size=(w, h), bg_color=bg_color)
    log.info(f"[fit_contain] out={out.w}x{out.h}")
    return out


from moviepy.video.fx.all import crop

def fit_clip_cover_strict(clip, w: int, h: int):
    s = max(w / clip.w, h / clip.h)   # uniform scale -> no stretch
    clip = clip.resize(s)
    return crop(clip, width=w, height=h, x_center=clip.w/2, y_center=clip.h/2)

# Duration planning (iOS Memory-like pacing)
IMG_MIN, IMG_IDEAL, IMG_MAX = 1.2, 2.0, 3.0
VID_MIN, VID_CAP_DEFAULT = 2.0, 5.0

def plan_durations(
    kinds: List[str],
    raw_vid_durs: List[Optional[float]],
    req_maxlens: List[Optional[float]],
    target: float,
    xfade_requested: float,
) -> Tuple[List[float], float]:
    n = len(kinds)
    vid_caps = [
        max(VID_MIN, (req_maxlens[i] if req_maxlens[i] else VID_CAP_DEFAULT))
        if kinds[i] == "video" else None
        for i in range(n)
    ]
    d = []
    for i in range(n):
        if kinds[i] == "image":
            d.append(IMG_IDEAL)
        else:
            raw = raw_vid_durs[i] or VID_MIN
            cap = vid_caps[i] or VID_CAP_DEFAULT
            d.append(min(max(VID_MIN, raw), cap))

    def eff_out(total, fade):
        return total - fade * (n - 1)

    total = sum(d)
    xfade = max(0.0, xfade_requested)
    if eff_out(total, xfade) > target:
        scale = (target + xfade * (n - 1)) / max(total, 1e-6)
        d = [max(IMG_MIN if kinds[i] == "image" else VID_MIN, di * scale) for i, di in enumerate(d)]
    else:
        short = target - eff_out(total, xfade)
        if short > 0:
            for i in range(n):
                if kinds[i] == "image":
                    room = IMG_MAX - d[i]
                    grow = min(room, short / max(1, n))
                    if grow > 0:
                        d[i] += grow
                        short -= grow
            for i in range(n):
                if kinds[i] == "video":
                    cap = vid_caps[i] or VID_CAP_DEFAULT
                    room = cap - d[i]
                    grow = min(room, short / max(1, n))
                    if grow > 0:
                        d[i] += grow
                        short -= grow
            if short > 0:
                for i in range(n):
                    cap = (IMG_MAX if kinds[i] == "image" else (vid_caps[i] or VID_CAP_DEFAULT))
                    room = cap - d[i]
                    grow = min(room, short / n)
                    if grow > 0:
                        d[i] += grow
                        short -= grow

    if n > 1:
        max_allowed = min(d[i] * 0.40 for i in range(1, n))
        xfade = max(0.0, min(xfade, max_allowed))
    else:
        xfade = 0.0

    return d, xfade

def cap_fade_for_clip(xfade: float, duration: float) -> float:
    return max(0.0, min(xfade, duration * 0.40))

# -------------
# Health route
# -------------
@app.get("/")
def health():
    return {"ok": True, "mode": "local", "ffmpeg": "required", "instructions": "POST /render-local"}

# ----------------
# Local rendering
# ----------------
@app.post("/render-local", response_model=RenderResponse)
def render_local(req: RenderRequest):
    if not req.clips:
        raise HTTPException(400, "No clips provided")

    # Lazy imports so the app boots even if video libs hiccup
    from moviepy.editor import ImageClip, VideoFileClip, concatenate_videoclips
    from moviepy.video.fx import all as vfx

    w, h, fps = req.video.width, req.video.height, req.video.fps
    target = min(max(req.targetSeconds or 60.0, 5.0), 120.0)
    mode = (req.fitMode or "cover").lower().strip()
    fit_fn = fit_clip_cover if mode == "cover" else fit_clip_contain

    # Pass 1: materialize local temps & gather durations
    local_paths: List[str] = []
    kinds: List[str] = []
    raw_vid_durs: List[Optional[float]] = []
    req_maxlens: List[Optional[float]] = []

    for idx, c in enumerate(req.clips):
        tmp = _download_or_copy_to_tmp(c.gcsPath)
        local_paths.append(tmp)
        # auto-detect type if missing
        ctype = c.type
        if ctype is None:
            if _is_video_ext(c.gcsPath):
                ctype = "video"
            elif _is_image_ext(c.gcsPath):
                ctype = "image"
            else:
                raise HTTPException(400, f"Cannot infer type for: {c.gcsPath}")
        kinds.append(ctype)
        req_maxlens.append(c.maxLen)

        if ctype == "video":
            v = VideoFileClip(tmp)
            raw_vid_durs.append(float(v.duration))
            v.close()
        else:
            raw_vid_durs.append(None)

    # Plan durations
    planned, xfade = plan_durations(kinds, raw_vid_durs, req_maxlens, target, req.crossfade)

    # Pass 2: build timeline (cover/contain modes)
    built = []
    for i, c in enumerate(req.clips):
        local = local_paths[i]
        dur = planned[i]

        if kinds[i] == "image":
            base = ImageClip(local)
            clip = fit_fn(base, w, h)
            kz = req.kenBurns.zoom if req.kenBurns else 0.0
            clip = clip.resize(lambda t, _dur=dur, _kz=kz: 1.0 + _kz * (t / max(_dur, 0.001))).set_duration(dur)

        else:
 
            # v_raw = VideoFileClip(local)
            # if dur < v_raw.duration:
            #     v_raw = v_raw.subclip(0, dur)

            # # normalize rotation & SAR so fit() is predictable
            # rot, sn, sd = _probe_geom(local)
            # log.info(f"[local clip {i}] rot={rot}, SAR={sn}:{sd}, dur={v_raw.duration:.2f}s")
             # clip = fit_fn(v_raw, w, h)
             
             
            # Corrected Video handling
            # v_raw = VideoFileClip(local)

            # # Check for MoviePy's rotation attribute and apply the fix
            # if v_raw.rotation in (90, 270):
            #     v_raw = v_raw.resize((v_raw.h, v_raw.w)) # swap dimensions
            # elif v_raw.rotation == 180:
            #     # no dimension swap needed for 180
            #     pass 
            # v_raw.rotation = 0 # reset rotation metadata for MoviePy

            # if dur < v_raw.duration:
            #     v_raw = v_raw.subclip(0, dur)

            # # Now, fit the physically correct clip
            # clip = fit_fn(v_raw, w, h)
            
            
            # v_raw = VideoFileClip(local)
            
            # # Use MoviePy's rotation attribute to apply the vfx.rotate effect
            # # The 'expand=True' ensures the canvas is resized to fit the rotated video
            # if v_raw.rotation in (90, 270):
            #     v_raw = v_raw.fx(vfx.rotate, -v_raw.rotation, expand=True)
            # elif v_raw.rotation == 180:
            #     v_raw = v_raw.fx(vfx.rotate, -v_raw.rotation, expand=True)
            
            # # The .rotation attribute is now 0 after the rotation is applied
            # v_raw.rotation = 0

            # # Now, apply the subclip and the fitting logic to the corrected video
            # if dur < v_raw.duration:
            #     v_raw = v_raw.subclip(0, dur)

            # # Fit the physically correct clip to the target dimensions (1080x1920)
            # clip = fit_fn(v_raw, w, h)
            
            
            
            # Load the video file
            v_raw = VideoFileClip(local)

            # Apply rotation and SAR correction
            # This is crucial for correctly orienting the video before resizing
            if v_raw.rotation in (90, 270):
                v_raw = v_raw.fx(vfx.rotate, -v_raw.rotation, expand=True)
            elif v_raw.rotation == 180:
                v_raw = v_raw.fx(vfx.rotate, -v_raw.rotation, expand=True)

            # Manually resize the clip to the target dimensions (1080x1920)
            # This is the key step to normalize all videos to your desired resolution.
            v_raw = v_raw.resize(newsize=(w, h))

            # Now, you can apply your subclip logic
            if dur < v_raw.duration:
                v_raw = v_raw.subclip(0, dur)

            # Since the video is now already 1080x1920, you don't need a separate fit_fn call
            clip = v_raw


            if clip.audio and xfade > 0:
                d = cap_fade_for_clip(xfade, dur)
                clip = clip.audio_fadein(d).audio_fadeout(d)
 

        if i > 0 and xfade > 0:
            d = cap_fade_for_clip(xfade, dur)
            clip = clip.crossfadein(d)

        built.append(clip)

    if not built:
        raise HTTPException(400, "No valid clips built")

    final_v = concatenate_videoclips(built, method="compose", padding=-xfade)



    # Save to Desktop
    desktop = os.path.join(os.path.expanduser("~"), "Desktop")
    os.makedirs(desktop, exist_ok=True)
    out_path = os.path.join(desktop, f"reel_local_{int(time.time())}.mp4")

    final_v.write_videofile(
        out_path,
        fps=fps,
        codec="libx264",
        audio_codec="aac",
        threads=2,
        preset="veryfast",
        bitrate="3500k",
        ffmpeg_params=[
        "-pix_fmt","yuv420p",
        "-movflags","+faststart",
        "-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2,setsar=1",
        "-map_metadata","-1",          # drop container metadata
        "-metadata:s:v:0","rotate=0",  # clear stream rotate
        "-metadata","rotate=0",        # clear container-level rotate if any
    ],
        
    
        # ffmpeg_params=[
        #     "-pix_fmt","yuv420p",
        #     "-movflags","+faststart",
        #     "-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2,setsar=1",
        #     "-metadata:s:v:0","rotate=0",
        # ],
    )
    
    try:
        final_v.close()
    except Exception:
        pass
    
    rot_out = _ffprobe_rotation(out_path)
    log.info("[write] output rotation metadata (before strip) = %d°", rot_out)
    if rot_out != 0:
        _strip_rotation_inplace(out_path)
        rot2 = _ffprobe_rotation(out_path)
        log.info("[write] after strip, rotation metadata = %d°", rot2)


    # Cleanup temp inputs
    for p in local_paths:
        try: os.remove(p)
        except Exception: pass

    return RenderResponse(output=out_path, duration=float(final_v.duration))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("local_app:app", host="127.0.0.1", port=8000, reload=True)
