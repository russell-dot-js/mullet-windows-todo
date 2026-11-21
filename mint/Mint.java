import java.io.*;
import java.lang.invoke.MethodHandles;
import java.lang.invoke.MethodType;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;

// The mint only licenses the six JVM instructions used by its serial-number die.
class Mint {
    static byte[] assemble(Path sheet) throws IOException {
        var bytes = new ByteArrayOutputStream();
        var code = new DataOutputStream(bytes);
        for (String line : Files.readAllLines(sheet)) {
            String[] parts = line.split(" ", -1);
            switch (parts[0]) {
                case "bipush":
                case "sipush":
                    if (parts.length != 2) throw new IOException(line);
                    if (parts[0].equals("bipush")) {
                        code.writeByte(0x10);
                        code.writeByte(Byte.parseByte(parts[1]));
                    } else {
                        code.writeByte(0x11);
                        code.writeShort(Short.parseShort(parts[1]));
                    }
                    break;
                default:
                    if (line.equals("iload_0")) code.writeByte(0x1a);
                    else if (line.equals("imul")) code.writeByte(0x68);
                    else if (line.equals("iadd")) code.writeByte(0x60);
                    else if (line.equals("ireturn")) code.writeByte(0xac);
                    else throw new IOException("Unlicensed engraving: " + line);
            }
        }
        if (bytes.size() > 65535) throw new IOException("Die exceeds the JVM method size limit");
        return bytes.toByteArray();
    }

    static void utf(DataOutputStream out, String value) throws IOException {
        out.writeByte(1);
        out.writeUTF(value);
    }

    // Classfile containing a single public static int strike(int) method.
    static byte[] die(byte[] instructions) throws IOException {
        var bytes = new ByteArrayOutputStream();
        var out = new DataOutputStream(bytes);
        out.writeInt(0xcafebabe);
        out.writeShort(0);
        out.writeShort(55);
        out.writeShort(8); // constant pool, including reserved slot zero
        utf(out, "SerialDie");
        out.writeByte(7); out.writeShort(1);
        utf(out, "java/lang/Object");
        out.writeByte(7); out.writeShort(3);
        utf(out, "strike");
        utf(out, "(I)I");
        utf(out, "Code");
        out.writeShort(0x21); out.writeShort(2); out.writeShort(4);
        out.writeShort(0); // interfaces
        out.writeShort(0); // fields
        out.writeShort(1); // methods
        out.writeShort(9); out.writeShort(5); out.writeShort(6);
        out.writeShort(1); out.writeShort(7); // one Code attribute
        out.writeInt(12 + instructions.length);
        out.writeShort(2); out.writeShort(1); // stack and local slots
        out.writeInt(instructions.length); out.write(instructions);
        out.writeShort(0); out.writeShort(0); // handlers and code attributes
        out.writeShort(0); // class attributes
        return bytes.toByteArray();
    }

    public static void main(String[] args) throws Throwable {
        var lookup = MethodHandles.lookup();
        var mint = lookup.defineClass(die(assemble(Path.of(args[0]))));
        var strike = lookup.findStatic(mint, "strike", MethodType.methodType(int.class, int.class));
        // A desktop clerk may submit one ASCII docket as an argument. Batch printers use stdin.
        Reader records = args.length == 2 ? new StringReader(args[1]) :
                new InputStreamReader(System.in, StandardCharsets.UTF_8);
        var input = new BufferedReader(records);
        for (String seal; (seal = input.readLine()) != null;) {
            int serial = (int) strike.invokeExact(seal.hashCode());
            System.out.println(Integer.toUnsignedString(serial, 16));
        }
    }
}
