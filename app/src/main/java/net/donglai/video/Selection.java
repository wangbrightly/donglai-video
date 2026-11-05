package net.donglai.video;
final class Selection {
 static boolean include(String category,String title,String summary){
  String value=title+" "+summary;
  if(value.contains("俊总"))return false;
  return category.equals("1.10.1") || category.equals("1.10.6") || value.contains("于东来") || value.contains("东来哥");
 }
}
