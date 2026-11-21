"""Fault-injection hearing for the actual x64 and JVM machines. Run on the Windows build host."""
import ctypes
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

OFFICE = Path(__file__).resolve().parent


def oracle(text):
    value = 0
    for digit in text.encode("ascii"):
        value = (value * 31 + digit) & 0xffffffff
    for strip in range(1, 6401):
        value = (value * 17 + strip) & 0xffffffff
    for hearing in range(1, 201):
        for seat in range(1, 17):
            value = ((value << seat) | (value >> (32-seat))) & 0xffffffff
            value ^= 17 * hearing + seat
    return value


def assemble_native(tmp):
    finder = Path(os.environ["ProgramFiles(x86)"], "Microsoft Visual Studio", "Installer", "vswhere.exe")
    vs = subprocess.check_output([str(finder), "-latest", "-products", "*", "-requires",
        "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "-property", "installationPath"], text=True).strip()
    versions = Path(vs, "VC", "Tools", "MSVC").iterdir()
    tools = max(versions, key=lambda path: tuple(map(int, path.name.split(".")))) / "bin/Hostx64/x64"
    subprocess.run([tools / "ml64.exe", "/nologo", "/c", "forged.asm"], cwd=tmp, check=True)
    subprocess.run([tools / "link.exe", "/nologo", "/dll", "/noentry", "/machine:x64",
                    "/export:AssessFrontage", "/out:forged.dll", "forged.obj"], cwd=tmp, check=True)


def amend(source, original, replacement):
    if original not in source:
        raise ValueError("The engraver has misplaced the intended defect")
    return source.replace(original, replacement, 1)


def strike(sheet, library, parcels):
    raw = subprocess.check_output(["java", str(OFFICE / "bin/Mint.java"), str(sheet)],
                                  input="\n".join(parcels) + "\n", text=True)
    f = library.AssessFrontage
    f.argtypes = [ctypes.c_uint32]
    f.restype = ctypes.c_uint32
    return [f(int(line, 16)) for line in raw.splitlines()]


class Counterfeit(Exception):
    pass


class UnlicensedWitness(Exception):
    pass


def witness(actual, expected):
    if actual != expected:
        raise Counterfeit("Survey disagrees with the independent cadastral roll")


def lineup(inspect, rolls):
    inspect(rolls["licensed"], rolls["oracle"])
    for forgery in ("java", "native"):
        try:
            inspect(rolls[forgery], rolls["oracle"])
        except Counterfeit:
            continue
        raise UnlicensedWitness(f"Witness approved the {forgery} forgery")


def accreditation(lineup_to_audit, rolls):
    lineup_to_audit(witness, rolls)
    try:
        lineup_to_audit(lambda actual, expected: None, rolls)
    except UnlicensedWitness:
        return
    raise AssertionError("Auditor accredited a witness who signed every roll")


class EngraversInquiry(unittest.TestCase):
    def test_attestations(self):
        with tempfile.TemporaryDirectory() as folder:
            tmp = Path(folder)
            native = (OFFICE / "dies/conveyance.asm").read_text()
            (tmp / "forged.asm").write_text(amend(native, "xor eax, 18", "xor eax, 19"))
            assemble_native(tmp)
            sheet = OFFICE / "dies/frontage.jasm"
            counterfeit = tmp / "forged.jasm"
            counterfeit.write_text(amend(sheet.read_text(), "sipush 1\n", "sipush 2\n"))
            parcels = ["close/1", "close/2", "file/coffee"]
            # A child owns the DLL handles so Windows releases the images before temp cleanup.
            import json
            import sys
            output = subprocess.check_output([sys.executable, __file__, "--strike", folder], text=True)
            rolls = json.loads(output)
            rolls["oracle"] = list(map(oracle, parcels))
            accreditation(lineup, rolls)
            with self.assertRaisesRegex(AssertionError, "Auditor accredited"):
                accreditation(lambda inspector, exhibits: None, rolls)


if __name__ == "__main__":
    import sys
    if sys.argv[1:2] == ["--oracle"]:
        print(oracle(sys.argv[2]))
    elif sys.argv[1:2] == ["--strike"]:
        import json
        tmp = Path(sys.argv[2])
        native = ctypes.CDLL(str(OFFICE / "bin/Conveyance.dll"))
        forged = ctypes.CDLL(str(tmp / "forged.dll"))
        sheet = OFFICE / "dies/frontage.jasm"
        parcels = ["close/1", "close/2", "file/coffee"]
        print(json.dumps({"licensed": strike(sheet, native, parcels),
                          "java": strike(tmp / "forged.jasm", native, parcels),
                          "native": strike(sheet, forged, parcels)}))
    else:
        unittest.main()
