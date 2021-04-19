Map<String, dynamic> removeJsonNull(Map<String, dynamic> map) {
  Map<String, dynamic> data = {};
  map.forEach((key, value) {
    if (value != null) data[key] = value;
  });

  return data;
}