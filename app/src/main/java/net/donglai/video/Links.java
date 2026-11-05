package net.donglai.video;
import java.net.URI;
final class Links {
 static boolean allowed(String url) {
  try { URI u = new URI(url); return "https".equalsIgnoreCase(u.getScheme()) && "baike.azpdl.net".equalsIgnoreCase(u.getHost()); } catch (Exception e) { return false; }
 }
}
