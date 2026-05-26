package protector.victims;

import java.awt.BorderLayout;
import java.awt.EventQueue;
import java.security.MessageDigest;
import javax.swing.JButton;
import javax.swing.JFrame;
import javax.swing.JPanel;
import javax.swing.JTextField;

public final class JavaSwingVictim {
    private JavaSwingVictim() {
    }

    public static void main(String[] args) {
        EventQueue.invokeLater(JavaSwingVictim::show);
    }

    private static void show() {
        JFrame frame = new JFrame("Java Swing Victim");
        JTextField input = new JTextField("matrix-safe");
        JTextField output = new JTextField();
        output.setEditable(false);
        JButton button = new JButton("Hash");

        button.addActionListener(event -> output.setText(input.getText() + " -> " + hash(input.getText())));
        JPanel panel = new JPanel(new BorderLayout(8, 8));
        panel.add(input, BorderLayout.NORTH);
        panel.add(output, BorderLayout.CENTER);
        panel.add(button, BorderLayout.SOUTH);

        frame.setContentPane(panel);
        frame.setSize(430, 170);
        frame.setLocationRelativeTo(null);
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        button.doClick();
        frame.setVisible(true);
    }

    private static String hash(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] bytes = digest.digest(value.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            StringBuilder builder = new StringBuilder();
            for (int i = 0; i < 12; i++) {
                builder.append(String.format("%02x", bytes[i]));
            }
            return builder.toString();
        } catch (Exception ex) {
            throw new IllegalStateException(ex);
        }
    }
}
