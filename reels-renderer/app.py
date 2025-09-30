











import os, tempfile, time, logging
from typing import List, Optional, Tuple

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from google.cloud import storage, firestore

# -------------------------------------------------------------------
# Pillow 10+ back-compat: some libs (or older paths) refer to ANTIALIAS
# -------------------------------------------------------------------
# try:
#     from PIL import Image as _PILImage  # noqa
#     if not hasattr(_PILImage, "ANTIALIAS") and hasattr(_PILImage, "Resampling"):
#         _PILImage.ANTIALIAS = _PILImage.Resampling.LANCZOS
# except Exception:
#     pass

# log = logging.getLogger("uvicorn")

import sys, logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    stream=sys.stdout,
    force=True,  # override uvicorn defaults
)

log = logging.getLogger(__name__)
app = FastAPI()

# =========================
# Models (request/response)
# =========================
class KenBurns(BaseModel):
    zoom: float = 0.07  # 7% zoom across the clip duration

class ClipIn(BaseModel):
    gcsPath: str                 # object path in your bucket (no "gs://")
    type: str                    # "image" | "video"
    maxLen: Optional[float] = None  # soft cap per video (sec); if omitted use global default

class VideoSpec(BaseModel):
    width: int = 1080
    height: int = 1920
    fps: int = 30

class RenderRequest(BaseModel):
    gatheringId: str
    targetSeconds: Optional[float] = 60.0   # iPhone-style memory reel cap
    crossfade: float = 0.5                  # requested fade; may be reduced for very short clips
    clips: List[ClipIn]
    kenBurns: Optional[KenBurns] = KenBurns()
    video: Optional[VideoSpec] = VideoSpec()
    fitMode: str = "cover"                  # "cover" (center-crop) or "contain" (letterbox)
    jobDocPath: Optional[str] = None        # Firestore doc path for progress (optional)

class RenderResponse(BaseModel):
    reelGsPath: str
    duration: float

# =========================
# Lazy clients / env config
# =========================
_GCS_CLIENT = None
_BUCKET = None
_FS_CLIENT = None

def get_bucket():
    global _GCS_CLIENT, _BUCKET
    if _BUCKET is not None:
        return _BUCKET
    bucket_name = os.environ.get("BUCKET")
    if not bucket_name:
        raise RuntimeError("BUCKET env var not set")
    _GCS_CLIENT = storage.Client()
    _BUCKET = _GCS_CLIENT.bucket(bucket_name)
    log.info(f"[renderer] Using bucket: {bucket_name}")
    return _BUCKET




import json, subprocess
from moviepy.video.fx import all as vfx

def _probe_geom(path: str):
    """Return (rotate_deg, sar_num, sar_den). Defaults to (0,1,1)."""
    cmd = [
        "ffprobe","-v","error","-select_streams","v:0",
        "-show_entries","stream=width,height,sample_aspect_ratio:stream_tags=rotate",
        "-of","json", path
    ]
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    rot, sn, sd = 0, 1, 1
    if p.returncode == 0:
        j = json.loads(p.stdout)
        if j.get("streams"):
            s = j["streams"][0]
            rot = int(s.get("tags",{}).get("rotate",0) or 0)
            sar = s.get("sample_aspect_ratio", "1:1")
            try:
                sn, sd = [int(x) for x in sar.split(":")]
            except Exception:
                pass
    return rot % 360, max(sn,1), max(sd,1)

def normalize_clip_for_fit(vclip, rot_deg: int, sar_num: int, sar_den: int):
    """Apply rotation & SAR so vclip.w/h reflect display geometry."""
    if rot_deg in (90,270):
        vclip = vclip.fx(vfx.rotate, rot_deg, expand=True)
    elif rot_deg == 180:
        vclip = vclip.fx(vfx.rotate, 180, expand=True)

    if sar_num != sar_den:
        vclip = vclip.fx(vfx.resize, (vclip.w * (sar_num/sar_den), vclip.h))

    return vclip




def get_fs():
    global _FS_CLIENT
    if _FS_CLIENT is None:
        _FS_CLIENT = firestore.Client()  # uses project from metadata
    return _FS_CLIENT

def job_update(job_path: Optional[str], data: dict):
    """Update Firestore job doc for UI progress (no-op if None)."""
    if not job_path:
        return
    fs = get_fs()
    fs.document(job_path).set(data, merge=True)
    
    
    
def fit_clip_cover_smart(clip, w: int, h: int, rot_deg: int):
    """Fill canvas without stretch, honoring rotation metadata (no actual rotate)."""
    from moviepy.video.compositing.CompositeVideoClip import CompositeVideoClip
    swap = (rot_deg % 180) != 0
    # Effective display dimensions (do NOT rotate frames)
    cw, ch = (clip.h, clip.w) if swap else (clip.w, clip.h)
    scale = max(w / cw, h / ch)
    clip = clip.resize(scale)
    return CompositeVideoClip([clip.set_position("center")], size=(w, h))

def fit_clip_contain_smart(clip, w: int, h: int, rot_deg: int, bg_color=(0,0,0)):
    """Letterbox/pillarbox without stretch, honoring rotation metadata."""
    from moviepy.video.compositing.CompositeVideoClip import CompositeVideoClip
    swap = (rot_deg % 180) != 0
    cw, ch = (clip.h, clip.w) if swap else (clip.w, clip.h)
    scale = min(w / cw, h / ch)
    clip = clip.resize(scale)
    return CompositeVideoClip([clip.set_position("center")], size=(w, h), bg_color=bg_color)




    

# =========================
# Utilities
# =========================
def download_gcs_to_tmp(object_path: str) -> str:
    """Download one object from GCS to a temp file; return local path."""
    b = get_bucket()
    blob = b.blob(object_path)
    if not blob.exists():
        raise FileNotFoundError(f"GCS object not found: {object_path}")
    fd, tmp = tempfile.mkstemp(prefix="media_", suffix=os.path.splitext(object_path)[1])
    os.close(fd)
    blob.download_to_filename(tmp)
    return tmp

# Fit helpers (no stretching)
def fit_clip_cover(clip, w: int, h: int):
    """Scale to fill (center-crop overflow) without distortion."""
    from moviepy.video.compositing.CompositeVideoClip import CompositeVideoClip
    scale = max(w / clip.w, h / clip.h)
    clip = clip.resize(scale)
    return CompositeVideoClip([clip.set_position("center")], size=(w, h))

def fit_clip_contain(clip, w: int, h: int, bg_color=(0, 0, 0)):
    """Scale to fit inside canvas (letterbox) without distortion."""
    from moviepy.video.compositing.CompositeVideoClip import CompositeVideoClip
    scale = min(w / clip.w, h / clip.h)
    clip = clip.resize(scale)
    return CompositeVideoClip([clip.set_position("center")], size=(w, h), bg_color=bg_color)



def fit_clip_cover_strict(clip, w, h):
    from moviepy.video.fx.all import crop
    s = max(w / clip.w, h / clip.h)   # uniform scale ⇒ no stretch
    clip = clip.resize(s)
    return crop(clip, width=w, height=h, x_center=clip.w/2, y_center=clip.h/2)



# Duration planning (iOS Memory-like pacing)
IMG_MIN, IMG_IDEAL, IMG_MAX = 1.2, 2.0, 3.0
VID_MIN, VID_CAP_DEFAULT = 2.0, 5.0  # default video cap (sec)

def plan_durations(
    kinds: List[str],
    raw_vid_durs: List[Optional[float]],
    req_maxlens: List[Optional[float]],
    target: float,
    xfade_requested: float,
) -> Tuple[List[float], float]:
    """
    Return (per-clip durations, effective_crossfade).
    Strategy:
      * start with image=2s ideal (1.2..3s), video=min(raw, cap) with min 2s
      * scale down if too long; if short, top-up images (to 3s) then videos (to cap)
      * choose a single crossfade <= 40% of any non-first clip
    """
    n = len(kinds)
    # caps per video
    vid_caps = [
        max(VID_MIN, (req_maxlens[i] if req_maxlens[i] else VID_CAP_DEFAULT))
        if kinds[i] == "video" else None
        for i in range(n)
    ]

    # initial proposal
    d = []
    for i in range(n):
        if kinds[i] == "image":
            d.append(IMG_IDEAL)
        else:
            raw = raw_vid_durs[i] or VID_MIN
            cap = vid_caps[i] or VID_CAP_DEFAULT
            d.append(min(max(VID_MIN, raw), cap))

    def eff_out(total, fade):  # effective output with overlap
        return total - fade * (n - 1)

    total = sum(d)
    xfade = max(0.0, xfade_requested)

    if eff_out(total, xfade) > target:
        # shrink proportionally respecting mins
        scale = (target + xfade * (n - 1)) / max(total, 0.001)
        d = [max(IMG_MIN if kinds[i] == "image" else VID_MIN, di * scale) for i, di in enumerate(d)]
    else:
        # short -> top up within caps
        short = target - eff_out(total, xfade)
        if short > 0:
            # images first
            for i in range(n):
                if kinds[i] == "image":
                    room = IMG_MAX - d[i]
                    grow = min(room, short / max(1, n))
                    if grow > 0:
                        d[i] += grow
                        short -= grow
            # then videos
            for i in range(n):
                if kinds[i] == "video":
                    cap = vid_caps[i] or VID_CAP_DEFAULT
                    room = cap - d[i]
                    grow = min(room, short / max(1, n))
                    if grow > 0:
                        d[i] += grow
                        short -= grow
            # distribute any crumbs
            if short > 0:
                for i in range(n):
                    cap = (IMG_MAX if kinds[i] == "image" else (vid_caps[i] or VID_CAP_DEFAULT))
                    room = cap - d[i]
                    grow = min(room, short / n)
                    if grow > 0:
                        d[i] += grow
                        short -= grow

    # pick a safe crossfade
    if n > 1:
        max_allowed = min(d[i] * 0.40 for i in range(1, n))
        xfade = max(0.0, min(xfade, max_allowed))
    else:
        xfade = 0.0

    return d, xfade

def cap_fade_for_clip(xfade: float, duration: float) -> float:
    return max(0.0, min(xfade, duration * 0.40))

# =========================
# Routes
# =========================
@app.get("/")
def health():
    return {"ok": True, "bucketSet": bool(os.environ.get("BUCKET"))}

@app.post("/render", response_model=RenderResponse)
def render(req: RenderRequest):
    if not req.clips:
        raise HTTPException(400, "No clips provided")

    # Lazy import so the server can boot even if video libs hiccup
    from moviepy.editor import ImageClip, VideoFileClip, concatenate_videoclips
    from moviepy.video.fx import all as vfx
    from moviepy.video.fx.all import crop
    

    # Kick off progress
    job_update(req.jobDocPath, {
        "status": "running",
        "progress": 5,
        "startedAt": firestore.SERVER_TIMESTAMP
    })

    w, h, fps = req.video.width, req.video.height, req.video.fps
    target = min(max(req.targetSeconds or 60.0, 5.0), 120.0)  # clamp to sane range
    fit_fn = fit_clip_cover if req.fitMode.lower().strip() == "cover" else fit_clip_contain

    # Pass 1: download assets & probe durations
    local_paths: List[str] = []
    kinds: List[str] = []
    raw_vid_durs: List[Optional[float]] = []
    req_maxlens: List[Optional[float]] = []

    try:
        for idx, c in enumerate(req.clips):
            local = download_gcs_to_tmp(c.gcsPath)
            local_paths.append(local)
            kinds.append(c.type)
            req_maxlens.append(c.maxLen)

            if c.type == "video":
                v = VideoFileClip(local)
                raw_vid_durs.append(float(v.duration))
                v.close()
            else:
                raw_vid_durs.append(None)

            # progress ~5→55 while fetching
            job_update(req.jobDocPath, {"progress": 5 + int(50 * (idx + 1) / max(1, len(req.clips)))})

        # Duration plan + effective crossfade
        planned, xfade = plan_durations(kinds, raw_vid_durs, req_maxlens, target, req.crossfade)

        # Pass 2: build timeline
        job_update(req.jobDocPath, {"stage": "building", "progress": 60})
        built = []
        for i, c in enumerate(req.clips):
            local = local_paths[i]
            dur = planned[i]
            if c.type == "image":
                base = ImageClip(local)
                clip = fit_fn(base, w, h)
                dur = planned[i]
                kz = req.kenBurns.zoom if req.kenBurns else 0.0
                def zoomf(t, _dur=dur, _kz=kz): return 1.0 + _kz * (t / max(_dur, 0.001))
                clip = clip.resize(lambda t: zoomf(t)).set_duration(dur)
            
            else:
                # v_raw = VideoFileClip(local)

                # # duration
                # dur = planned[i]
                # if dur < v_raw.duration:
                #     v_raw = v_raw.subclip(0, dur)

                # # --- probe + normalize ---
                # rot, sn, sd = _probe_geom(local)
                # log.info(f"[clip {i}] RAW {v_raw.w}x{v_raw.h}, rot={rot}, SAR={sn}:{sd}, dur={v_raw.duration:.2f}s")

                # v = normalize_clip_for_fit(v_raw, rot, sn, sd)
                # log.info(f"[clip {i}] NORM {v.w}x{v.h}, AR={v.w/v.h:.4f}, target AR={w/h:.4f}")

                # # fit
                # if req.fitMode.lower().strip() == "cover":
                #     clip = fit_clip_cover(v, w, h)
                # else:
                #     clip = fit_clip_contain(v, w, h)
                
                v_raw = VideoFileClip(local)

                # Apply rotation and SAR correction
                # This is crucial for correctly orienting the video before resizing
                # if v_raw.rotation in (90, 270):
                #     v_raw = v_raw.fx(vfx.rotate, -v_raw.rotation, expand=True)
                # elif v_raw.rotation == 180:
                #     v_raw = v_raw.fx(vfx.rotate, -v_raw.rotation, expand=True)

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
                d = cap_fade_for_clip(xfade, planned[i])
                clip = clip.crossfadein(d)

            built.append(clip)

        if not built:
            raise HTTPException(400, "No valid clips")

        # Encode
        job_update(req.jobDocPath, {"stage": "encoding", "progress": 75})
        final_v = concatenate_videoclips(built, method="compose", padding=-xfade)
        out_path = os.path.join(tempfile.gettempdir(), f"reel_{int(time.time())}.mp4")
          

        final_v.write_videofile(
        out_path,
        fps=fps,
        codec="libx264",
        audio_codec="aac",
        threads=2,
        preset="veryfast",
        bitrate="3500k",
        ffmpeg_params=[
            "-pix_fmt", "yuv420p",
            "-movflags", "+faststart",
            # Clear all rotation metadata
            "-map_metadata", "-1",
            "-metadata:s:v:0", "rotate=0",
            "-metadata", "rotate=0",
        ],
    #     ffmpeg_params=[
    #     "-pix_fmt","yuv420p",
    #     "-movflags","+faststart",
    #     "-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2,setsar=1",
    #     "-map_metadata","-1",          # drop container metadata
    #     "-metadata:s:v:0","rotate=0",  # clear stream rotate
    #     "-metadata","rotate=0",        # clear container-level rotate if any
    # ],
    #     ffmpeg_params=[
    #     "-pix_fmt", "yuv420p",
    #     "-movflags", "+faststart",
    #     # Clear all rotation metadata
    #     "-map_metadata", "-1",
    #     "-metadata:s:v:0", "rotate=0",
    #     "-metadata", "rotate=0",
    # ],
    
        # ffmpeg_params=[
        #     "-pix_fmt","yuv420p",
        #     "-movflags","+faststart",
        #     # just ensure even dims & square pixels; no geometry change now
        #     "-vf","pad=ceil(iw/2)*2:ceil(ih/2)*2,setsar=1",
        #     "-metadata:s:v:0","rotate=0"
        # ],
    )


        # Upload
        job_update(req.jobDocPath, {"stage": "uploading", "progress": 95})
        reel_gcs_path = f"reels/{req.gatheringId}/{int(time.time())}.mp4"
        get_bucket().blob(reel_gcs_path).upload_from_filename(out_path, content_type="video/mp4")

        # Done
        job_update(req.jobDocPath, {
            "status": "done",
            "progress": 100,
            "gcsPath": reel_gcs_path,
            "duration": float(final_v.duration),
            "finishedAt": firestore.SERVER_TIMESTAMP,
        })

        # (MoviePy clips are GC'd; ensure file is removed below)
        return RenderResponse(reelGsPath=reel_gcs_path, duration=float(final_v.duration))

    except HTTPException:
        # pass through
        raise
    except Exception as e:
        log.exception("Render failed")
        job_update(req.jobDocPath, {
            "status": "error",
            "progress": 100,
            "error": str(e),
            "finishedAt": firestore.SERVER_TIMESTAMP,
        })
        raise HTTPException(500, f"Render failed: {e}")
    finally:
        # cleanup temp files
        for p in local_paths:
            try: os.remove(p)
            except Exception: pass
        # also try to remove the output if it exists
        try:
            # out_path may not exist if we failed early
            if 'out_path' in locals() and out_path and os.path.exists(out_path):
                os.remove(out_path)
        except Exception:
            pass
        
        


        
