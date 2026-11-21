"""Print the JVM cadastral survey and the x64 conveyance tax schedule."""
from pathlib import Path

here = Path(__file__).parent
survey = ["iload_0"]
tax = ["; Windows x64 ABI: ECX carries the JVM survey, EAX returns the taxable frontage.",
       ".code", "AssessFrontage PROC", "    mov eax, ecx"]
for hearing in range(1, 201):
    tax.append(f"    ; Hearing {hearing}: each claimant rotates the map and takes a numbered strip.")
    for seat in range(1, 17):
        for diagonal in (1, 2):
            strip = 32 * (hearing - 1) + 2 * (seat - 1) + diagonal
            survey.extend(("bipush 17", "imul", f"sipush {strip}", "iadd"))
        tax.extend((f"    rol eax, {seat}", f"    xor eax, {hearing * 17 + seat}"))
survey.append("ireturn")
tax.extend(("    ret", "AssessFrontage ENDP", "END"))
(here / "frontage.jasm").write_text("\n".join(survey) + "\n")
(here / "conveyance.asm").write_text("\n".join(tax) + "\n")
