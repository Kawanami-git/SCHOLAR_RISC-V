from elftools.elf.elffile import ELFFile
import sys

def is_memory_section(section):
    return section['sh_flags'] & 0x2  # SHF_ALLOC

def is_code_section(section):
    return section['sh_flags'] & 0x4  # SHF_EXECINSTR

def extract_words(section):
    addr = section['sh_addr']
    data = section.data()
    words = []

    for i in range(0, len(data), 4):
        word = data[i:i+4]
        if len(word) < 4:
            word += b'\x00' * (4 - len(word))
        hexword = "%02x%02x%02x%02x" % (word[3], word[2], word[1], word[0])
        if hexword != "00000000":
            words.append((addr, hexword))
        addr += 4

    return words

def main():
    if len(sys.argv) < 2:
        print("Usage: python make_hex.py firmware.elf")
        return

    elf_path = sys.argv[1]

    with open(elf_path, 'rb') as f:
        elf = ELFFile(f)

        all_words = []
        code_size = 0
        data_size = 0

        for section in elf.iter_sections():
            if not is_memory_section(section):
                continue

            words = extract_words(section)
            all_words.extend(words)

            size = len(words) * 4
            if is_code_section(section):
                code_size += size
            else:
                data_size += size

        # Sort per address
        all_words.sort(key=lambda x: x[0])

        for addr, data in all_words:
            print(f"{addr:08x}:{data}")

if __name__ == "__main__":
    main()
