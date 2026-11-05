package net.donglai.video;
import org.junit.Test;
import static org.junit.Assert.*;
public class SelectionTest {
 @Test public void selectsRelevantCategoriesAndExplicitMentions() {
  assertTrue(Selection.include("1.10.1", "幸福哲学", ""));
  assertTrue(Selection.include("1.10.6", "生命在于释放", ""));
  assertTrue(Selection.include("1.10.2", "分享会", "于东来发言"));
  assertFalse(Selection.include("1.10.1", "俊总分享会", ""));
  assertFalse(Selection.include("1.10.2", "企业宣传片", ""));
 }
}
