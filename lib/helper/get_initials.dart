String getInitials(String name) {
  
  List<String> nameParts = name.trim().split(RegExp(r'\s+')); // Split by spaces
  String initials = nameParts.length > 1
      ? "${nameParts[0][0]}${nameParts[1][0]}" // First letter of first & last name
      : nameParts[0][0]; // If single name, just take the first letter

  return initials.toUpperCase();
}

// String getInitials(String name) {
//   if (name.trim().isEmpty) return "";

//   List<String> nameParts = name.trim().split(RegExp(r'\s+'));

//   if (nameParts.length > 1) {
//     return "${nameParts[0][0]}${nameParts[1][0]}".toUpperCase();
//   } else if (nameParts[0].isNotEmpty) {
//     return nameParts[0][0].toUpperCase();
//   } else {
//     return "";
//   }
// }

