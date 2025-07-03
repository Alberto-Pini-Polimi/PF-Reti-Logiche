import sys
import os

# --- Configurazione ---
DEFAULT_INPUT_FILENAME = "numeri.txt"
DEFAULT_OUTPUT_FILENAME = "output_accoppiato.txt" # Nuovo nome del file di output
# --------------------

def accoppia_numeri(numeri_str, output_file_path):
    """
    Prende una lista di stringhe (numeri uno per riga),
    li converte in interi, li divide a metà e li stampa a coppie affiancate
    su un file specificato.
    """
    # Filtra righe vuote e converti in interi
    numbers = []
    for s in numeri_str:
        s = s.strip() # Rimuovi spazi bianchi e newline
        if s: # Se la riga non è vuota
            try:
                numbers.append(int(s))
            except ValueError:
                print(f"Attenzione: Riga non valida ignorata: '{s}'", file=sys.stderr)
                
    if not numbers:
        print("Nessun numero valido trovato nell'input.", file=sys.stderr)
        return

    total_numbers = len(numbers)

    # Gestione del numero dispari di elementi
    if total_numbers % 2 != 0:
        print(f"Attenzione: Il numero totale di numeri è dispari ({total_numbers}). L'ultimo numero verrà ignorato.", file=sys.stderr)
        total_numbers -= 1 

    half_point = total_numbers // 2

    try:
        with open(output_file_path, 'w') as outfile: # Apre il file di output in modalità scrittura ('w')
            outfile.write("Numeri accoppiati:\n")
            outfile.write("------------------\n")
            print(f"Scrittura output su: {output_file_path}") # Messaggio per l'utente

            for i in range(half_point):
                num1 = numbers[i]
                num2 = numbers[i + half_point]
                # Scrive la stringa formattata nel file
                outfile.write(f"{num1:>6} {num2:>6}\n")
        print("Operazione completata con successo.")
    except IOError as e:
        print(f"Errore durante la scrittura del file '{output_file_path}': {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    input_source = None
    output_target = DEFAULT_OUTPUT_FILENAME # Imposta il file di output predefinito

    # 1. Controlla se è stato fornito un file di input come argomento
    if len(sys.argv) > 1:
        # Se ci sono 2 argomenti, il primo è l'input, il secondo l'output
        if len(sys.argv) == 3:
            input_source = sys.argv[1]
            output_target = sys.argv[2]
        # Se c'è solo 1 argomento, è l'input, usa l'output predefinito
        else: # len(sys.argv) == 2
            input_source = sys.argv[1]
    # 2. Altrimenti, prova a usare il file di input predefinito
    elif os.path.exists(DEFAULT_INPUT_FILENAME):
        input_source = DEFAULT_INPUT_FILENAME
    # 3. Altrimenti, leggi da input standard
    else:
        print(f"Nessun file di input specificato e il file di default '{DEFAULT_INPUT_FILENAME}' non trovato.")
        print("Inserisci i numeri (uno per riga). Premi Ctrl+D (o Ctrl+Z su Windows) e Invio per terminare:")
        input_lines = sys.stdin.readlines()
        accoppia_numeri(input_lines, output_target) # Passa il file di output
        sys.exit(0) # Termina qui se abbiamo letto da stdin

    # Se input_source è stato definito (o da argomento o da default file)
    if input_source:
        try:
            with open(input_source, 'r') as f:
                input_lines = f.readlines()
            accoppia_numeri(input_lines, output_target) # Passa il file di output
        except FileNotFoundError:
            print(f"Errore: Il file di input '{input_source}' non esiste.", file=sys.stderr)
            sys.exit(1)