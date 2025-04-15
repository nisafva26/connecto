String getInitials(String name) {
  List<String> nameParts = name.trim().split(RegExp(r'\s+')); // Split by spaces
  String initials = nameParts.length > 1
      ? "${nameParts[0][0]}${nameParts[1][0]}" // First letter of first & last name
      : nameParts[0][0]; // If single name, just take the first letter

  return initials.toUpperCase();
}
