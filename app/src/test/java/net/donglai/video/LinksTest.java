package net.donglai.video;
import org.junit.Test;
import static org.junit.Assert.*;
public class LinksTest {
 @Test public void onlyEncyclopediaPagesAreAllowed() {
  assertTrue(Links.allowed("https://baike.azpdl.net/#/entry/abc"));
  assertFalse(Links.allowed("https://baike.azpdl.net.evil.test/"));
  assertFalse(Links.allowed("http://baike.azpdl.net/"));
 }
}
