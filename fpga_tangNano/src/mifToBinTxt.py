import re
import sys

def convert_mif_to_vhdl_txt(input_file, output_file):
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Oczyszczenie komentarzy
    content_clean = re.sub(r'--.*', '', content)

    # Ekstrakcja głębokości
    depth_match = re.search(r'DEPTH\s*=\s*(\d+);', content_clean, re.IGNORECASE)
    if not depth_match:
        print("Błąd: Brak DEPTH w pliku mif.")
        sys.exit(1)
    
    depth = int(depth_match.group(1))
    
    # Inicjalizacja pustej pamięci (zera w formacie binarnym)
    memory = ["00000000"] * depth

    content_match = re.search(r'CONTENT\s+BEGIN(.*?)END;', content_clean, re.IGNORECASE | re.DOTALL)
    if not content_match:
        sys.exit(1)
        
    data_block = content_match.group(1)

    # Zmienna kontrolna dla błędów
    out_of_bounds_errors = 0

    # Wypełnianie adresów
    for stmt in data_block.split(';'):
        if ':' not in stmt:
            continue
            
        addr_part, vals_part = stmt.split(':', 1)
        try:
            current_addr = int(addr_part.strip(), 16) # Adres w pliku MIF traktowany jako HEX
        except ValueError:
            continue

        for val in vals_part.split():
            if current_addr < depth:
                # Konwersja HEX do formatu binarnego (8 bitów)
                bin_str = bin(int(val, 16))[2:].zfill(8)
                memory[current_addr] = bin_str
            else:
                print(f"[FATAL] Przekroczenie zakresu pamięci. Adres fizyczny: {current_addr} (Max: {depth-1}). Wartość '{val}' odrzucona.")
                out_of_bounds_errors += 1
            current_addr += 1

    if out_of_bounds_errors > 0:
        print(f"\nProces zakończony z błędami. Odrzucono {out_of_bounds_errors} bajtów poza zakresem DEPTH.")
        sys.exit(2)

    # Zapis do prostego pliku tekstowego
    with open(output_file, 'w', encoding='utf-8') as f:
        for val in memory:
            f.write(f"{val}\n")
            
    print(f"Konwersja zakończona sukcesem. Wygenerowano {depth} komórek.")

if __name__ == "__main__":
    convert_mif_to_vhdl_txt("initRAM.mif", "ram_init.txt")