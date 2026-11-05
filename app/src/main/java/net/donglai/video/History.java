package net.donglai.video;
final class History {
 static int move(int index,int delta,int count){return (index+delta+count)%count;}
 static String remove(String existing,String id){StringBuilder out=new StringBuilder();for(String entry:existing.split(",")){if(!entry.isEmpty()&&!entry.equals(id)){if(out.length()>0)out.append(',');out.append(entry);}}return out.toString();}
 static String record(String existing,String id){
  if(id==null||id.isEmpty())return existing;
  StringBuilder result=new StringBuilder(id);
  for(String old:existing.split(","))if(!old.isEmpty()&&!old.equals(id))result.append(',').append(old);
  return result.toString();
 }
}
