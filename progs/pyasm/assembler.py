import sys

# Таблица опкодов (Big Endian)
OPCODES = {
    # Регистровые операции
    'MOV': {'RR': 0x10, 'IMM8': 0x70},
    'ADD': {'RR': 0x20, 'IMM8': 0x80},
    'SUB': {'RR': 0x30, 'IMM8': 0x90},
    'AND': {'RR': 0x40, 'IMM8': 0xA0},
    'OR': {'RR': 0x50, 'IMM8': 0xB0},
    'XOR': {'RR': 0x60, 'IMM8': 0xC0},
    # Память и устройства
    'MOV_MEM': {'MEM': 0x90, 'REG': 0xA0},
    'IN': 0xD0,
    'OUT': 0xE0,
    # Управление потоком
    'JMP': 0xD0,
    'JZ': 0xD1,
    'JC': 0xD2,
    'CALL': 0xF3,
    # Одно-байтовые команды
    'NOP': 0x00,
    'HALT': 0xEF,
    'RET': 0xE4,
    'RETI': 0xE5,
    'EI': 0xF4,
    'DI': 0xF5
}

# Коды регистров
REGISTERS = {'A': 0, 'B': 1, 'C': 2, 'D': 3}

def parse_immediate(value, symbols=None):
    """Парсинг непосредственного значения или метки"""
    value = value.strip().upper()
    
    if symbols and value in symbols:
        return symbols[value]
    
    if value.startswith('0X'):
        return int(value[2:], 16)
    elif value.startswith('0B'):
        return int(value[2:], 2)
    elif value.startswith("'"):
        return ord(value[1])
    else:
        return int(value)

def parse_instruction(line, current_address, symbols=None, pass_num=1):
    """Разбор строки ассемблера в машинный код."""
    line = line.split(';')[0].strip()
    if not line:
        return [], current_address, None  # Возвращаем пустой список вместо None

    # Обработка меток
    if line.endswith(':'):
        label = line[:-1].strip()
        if not label:
            raise ValueError("Пустая метка")
        return [], current_address, label  # Возвращаем пустой список вместо None

    parts = [p.strip().upper() for p in line.replace(',', ' ').split() if p.strip()]
    if not parts:
        return [], current_address, None  # Возвращаем пустой список вместо None

    # Обработка директивы ORG
    if parts[0] == 'ORG':
        if len(parts) != 2:
            raise ValueError(f"Директива ORG требует одного аргумента (адрес), получено: {line}")
        try:
            new_address = parse_immediate(parts[1], symbols)
            if new_address < current_address and pass_num == 2:
                raise ValueError(f"Новый адрес ORG ({new_address:04X}) меньше текущего ({current_address:04X})")
            padding = new_address - current_address
            if padding < 0:
                return [], new_address, None  # Возвращаем пустой список вместо None
            return [0] * padding, new_address, None
        except ValueError as e:
            raise ValueError(f"Неправильный адрес в ORG: {e}")

    # Обработка директивы DB (Define Byte)
    if parts[0] == 'DB':
        if len(parts) < 2:
            raise ValueError("Директива DB требует хотя бы одного значения")
        
        bytes_to_write = []
        for value in parts[1:]:
            try:
                # Обработка строковых литералов
                if value.startswith('"') and value.endswith('"'):
                    for char in value[1:-1]:
                        bytes_to_write.append(ord(char))
                # Обработка числовых значений
                else:
                    byte_value = parse_immediate(value, symbols)
                    if byte_value > 0xFF:
                        raise ValueError(f"Значение {value} превышает 8 бит")
                    bytes_to_write.append(byte_value)
            except ValueError as e:
                raise ValueError(f"Неправильное значение для DB: {e}")
        
        return bytes_to_write, current_address + len(bytes_to_write), None

    # Обработка остальных команд (MOV, ADD, и т.д.)
    cmd = parts[0]
    
    if cmd in ['NOP', 'HALT', 'RET', 'RETI', 'EI', 'DI']:
        return [OPCODES[cmd]], current_address + 1, None
    
    if cmd in ['MOV', 'ADD', 'SUB', 'AND', 'OR', 'XOR']:
        if len(parts) != 3:
            raise ValueError(f"Неправильное число аргументов для {cmd}")

        dst, src = parts[1], parts[2]
        
        if dst.startswith('[') and dst.endswith(']'):
            if src not in REGISTERS:
                raise ValueError(f"Источник должен быть регистром, получено: {src}")
            try:
                addr = parse_immediate(dst[1:-1], symbols)
                if addr > 0xFFFF:
                    raise ValueError(f"Адрес {dst} превышает 16 бит")
                opcode = OPCODES['MOV_MEM']['MEM'] | REGISTERS[src]
                return [opcode, (addr >> 8) & 0xFF, addr & 0xFF], current_address + 3, None
            except ValueError:
                raise ValueError(f"Неправильный адрес: {dst}")
        
        elif src.startswith('[') and src.endswith(']'):
            if dst not in REGISTERS:
                raise ValueError(f"Приемник должен быть регистром, получено: {dst}")
            try:
                addr = parse_immediate(src[1:-1], symbols)
                if addr > 0xFFFF:
                    raise ValueError(f"Адрес {src} превышает 16 бит")
                opcode = OPCODES['MOV_MEM']['REG'] | REGISTERS[dst]
                return [opcode, (addr >> 8) & 0xFF, addr & 0xFF], current_address + 3, None
            except ValueError:
                raise ValueError(f"Неправильный адрес: {src}")
        
        elif dst in REGISTERS and src in REGISTERS:
            opcode = OPCODES[cmd]['RR']
            code = opcode | (REGISTERS[dst] << 2) | REGISTERS[src]
            return [code], current_address + 1, None
        
        elif dst in REGISTERS:
            try:
                imm = parse_immediate(src, symbols)
                if imm > 0xFF:
                    raise ValueError(f"Значение {src} превышает 8 бит")
                opcode = OPCODES[cmd]['IMM8'] | REGISTERS[dst]
                return [opcode, imm], current_address + 2, None
            except ValueError:
                raise ValueError(f"Неподдерживаемый источник для {cmd}: {src}")
        else:
            raise ValueError(f"Неподдерживаемый формат: {line}")

    elif cmd in ['IN', 'OUT']:
        if len(parts) != 3:
            raise ValueError(f"Неправильное число аргументов для {cmd}")
        
        if cmd == 'IN':
            reg, port = parts[1], parts[2]
            if reg not in REGISTERS:
                raise ValueError(f"Неправильный регистр для IN: {reg}")
            try:
                port_num = parse_immediate(port, symbols)
                if port_num > 0xFF:
                    raise ValueError(f"Номер порта {port} превышает 8 бит")
                opcode = OPCODES['IN'] | REGISTERS[reg]
                return [opcode, port_num], current_address + 2, None
            except ValueError:
                raise ValueError(f"Неправильный номер порта: {port}")
        else:
            port, reg = parts[1], parts[2]
            if reg not in REGISTERS:
                raise ValueError(f"Неправильный регистр для OUT: {reg}")
            try:
                port_num = parse_immediate(port, symbols)
                if port_num > 0xFF:
                    raise ValueError(f"Номер порта {port} превышает 8 бит")
                opcode = OPCODES['OUT'] | REGISTERS[reg]
                return [opcode, port_num], current_address + 2, None
            except ValueError:
                raise ValueError(f"Неправильный номер порта: {port}")

    elif cmd in ['JMP', 'JZ', 'JC', 'CALL']:
        if len(parts) != 2:
            raise ValueError(f"Неправильное число аргументов для {cmd}")
        try:
            addr = parse_immediate(parts[1], symbols)
            if addr > 0xFFFF:
                raise ValueError(f"Адрес {parts[1]} превышает 16 бит")
            return [OPCODES[cmd], (addr >> 8) & 0xFF, addr & 0xFF], current_address + 3, None
        except ValueError:
            if symbols is not None:
                raise ValueError(f"Неизвестная метка: {parts[1]}")
            return [], current_address + 3, None  # Возвращаем пустой список вместо None

    else:
        raise ValueError(f"Неизвестная команда: {cmd}")

def assemble(input_file, output_file):
    """Ассемблирование файла в машинный код."""
    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Первый проход: сбор меток
    symbols = {}
    current_address = 0
    
    for line_num, line in enumerate(lines, 1):
        line = line.strip()
        if not line or line.startswith(';'):
            continue
        
        try:
            code, new_address, label = parse_instruction(line, current_address, None, 1)
            if label:
                if label in symbols:
                    raise ValueError(f"Повторяющаяся метка: {label}")
                symbols[label] = current_address
            current_address = new_address
        except ValueError as e:
            print(f"Ошибка в строке {line_num}: '{line}': {e}")
            return

    # Второй проход: генерация кода
    machine_code = []
    current_address = 0
    
    for line_num, line in enumerate(lines, 1):
        line = line.strip()
        if not line or line.startswith(';'):
            continue
        
        try:
            code, new_address, _ = parse_instruction(line, current_address, symbols, 2)
            if code:
                machine_code.extend(code)
            current_address = new_address
        except ValueError as e:
            print(f"Ошибка в строке {line_num}: '{line}': {e}")
            return

    # Запись в выходной файл
    with open(output_file, 'wb') as f:
        f.write(bytes(machine_code))
    print(f"Ассемблирование завершено. Результат в {output_file} (размер: {len(machine_code)} байт)")

def binary_to_text(input_file, output_file, format_hex=True):
    """
    Читает бинарный файл и записывает его байты в текстовый файл.
    
    :param input_file: Путь к входному бинарному файлу.
    :param output_file: Путь к выходному текстовому файлу.
    :param format_hex: Если True, записывает байты в HEX-формате, иначе — в десятичном.
    """
    try:
        with open(input_file, 'rb') as bin_file:
            data = bin_file.read()
        
        with open(output_file, 'w') as txt_file:
            for byte in data:
                if format_hex:
                    txt_file.write(f"{byte:02X} ")  # Запись в HEX (например, "FF ")
                else:
                    txt_file.write(f"{byte} ")  # Запись в десятичном виде (например, "255 ")
        
        print(f"Успешно! Байты записаны в {output_file}")
    
    except FileNotFoundError:
        print("Ошибка: входной файл не найден.")
    except Exception as e:
        print(f"Произошла ошибка: {e}")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Использование: python assembler.py <input.asm> <output.bin>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    assemble(input_file, output_file)
    print("Create Hex file? Y - for create")
    if input() == "Y":
        binary_to_text(output_file, output_file+".hex", format_hex=True)