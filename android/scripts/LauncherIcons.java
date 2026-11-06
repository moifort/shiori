import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.geom.Ellipse2D;
import java.awt.image.BufferedImage;
import java.io.File;

/**
 * The launcher icons drawn from the iOS app icon: `java android/scripts/LauncherIcons.java
 * ios/Shiori/Assets.xcassets/AppIcon.appiconset/AppIcon.png android/app/src/main/res`. The
 * adaptive background extends the icon's edges so the mask never crops the book.
 */
public class LauncherIcons {
    static BufferedImage scale(BufferedImage src, int side) {
        BufferedImage out = new BufferedImage(side, side, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = out.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
        g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        g.drawImage(src, 0, 0, side, side, null);
        g.dispose();
        return out;
    }

    public static void main(String[] args) throws Exception {
        BufferedImage icon = ImageIO.read(new File(args[0]));
        String res = args[1];
        int n = icon.getWidth();
        int pad = (int) Math.round(n * 0.15);
        int side = n + 2 * pad;
        BufferedImage padded = new BufferedImage(side, side, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < side; y++) {
            int sy = Math.min(n - 1, Math.max(0, y - pad));
            for (int x = 0; x < side; x++) {
                int sx = Math.min(n - 1, Math.max(0, x - pad));
                padded.setRGB(x, y, icon.getRGB(sx, sy));
            }
        }
        String[] names = {"mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"};
        int[] legacy = {48, 72, 96, 144, 192};
        int[] adaptive = {108, 162, 216, 324, 432};
        for (int i = 0; i < names.length; i++) {
            File dir = new File(res, "mipmap-" + names[i]);
            dir.mkdirs();
            ImageIO.write(scale(padded, adaptive[i]), "png", new File(dir, "ic_launcher_background.png"));
            BufferedImage square = scale(icon, legacy[i]);
            ImageIO.write(square, "png", new File(dir, "ic_launcher.png"));
            BufferedImage round = new BufferedImage(legacy[i], legacy[i], BufferedImage.TYPE_INT_ARGB);
            Graphics2D g = round.createGraphics();
            g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
            g.setClip(new Ellipse2D.Float(0, 0, legacy[i], legacy[i]));
            g.drawImage(scale(padded, (int) (legacy[i] * 1.0)), 0, 0, null);
            g.dispose();
            ImageIO.write(round, "png", new File(dir, "ic_launcher_round.png"));
        }
    }
}
