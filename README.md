# Ассемблер и HDL для 8-битного процессора

## Описание проекта

Этот репозиторий содержит полный набор инструментов для разработки под 8-битный процессор с уникальной архитектурой:

- **Ассемблер** - преобразует текстовый код на ассемблере в бинарный машинный код
- **HDL реализация** - описание процессора на языке Verilog/VHDL
- **Инструменты разработки** - всё необходимое для создания программ и симуляции

## Особенности

### 🛠 Ассемблер

✅ **Полная поддержка ISA**:

- Все регистровые операции (MOV, ADD, SUB, AND, OR, XOR)
- Работа с памятью и портами ввода-вывода (IN/OUT)
- Команды управления потоком выполнения (JMP, CALL, RET)
- Прерывания (EI, DI, RETI)

✅ **Гибкая система адресации**:

- Поддержка меток (labels)
- Директива `ORG` для указания адреса размещения
- Относительные и абсолютные переходы

✅ **Двухпроходная компиляция**:

1. Первый проход: построение таблицы символов
2. Второй проход: генерация машинного кода

✅ **Проверка ошибок**:

- Синтаксические ошибки
- Неизвестные команды
- Переполнение значений
- Повторяющиеся метки

### ⚙️ HDL реализация

- Полное описание процессора на Verilog/VHDL
- Поддержка всех заявленных в ISA функций
- Тестовые стенды для верификации
- Возможность синтеза под ПЛИС

## Установка и использование

1. Клонируйте репозиторий:

```bash
git clone https://github.com/yourusername/8bit-cpu.git
cd 8bit-cpu
```

2. **Для работы с ассемблером**:

```bash
python assembler.py input.asm output.bin
```

Где:

- `input.asm` - исходный файл на ассемблере
- `output.bin` - выходной бинарный файл

3. **Для симуляции процессора**:

```bash
iverilog -o processor_tb.vvp -g2012 -s tb_processor .\src\ram.sv .\src\core.sv .\src\top.sv .\src\rtc.sv  .\tb\tb_processor.sv
>> vvp processor_tb.vvp 
```

4. **Для синтеза под ПЛИС**:

```bash
МОЛИТВЫ
```

## Структура репозитория

```
ether-simple-proc/
├── progs/pyasm/            # Исходный код ассемблера
│   ├── assembler.py          # ASSembler
├── src/                  # HDL реализация
│   ├── top.sv            # Основной модуль 
│   ├── core.v            # Ядро
│   ├── ram.v            # Память
│   └── tb/              # Тестовые скрипты
└── doc/                # Документация
```

## Пример программы

```asm
ORG 0x0000
MAIN:
    EI              ; Разрешаем прерывания
    MOV A, 0x55
    OUT 0x01, A     ; Выводим значение в порт 0x01
LOOP:
    JMP LOOP        ; Бесконечный цикл

ORG 0x1000
INTHANDLER:
    IN A, 0x00     ; Читаем данные из порта 0x00
    ADD A, 1
    OUT 0x01, A    ; Выводим результат в порт 0x01
    RETI           ; Возврат из прерывания

ORG 0xFFFE         ; Вектор прерываний
    JMP INTHANDLER ; Адрес обработчика прерываний
```

## Форматы команд

### Регистровые операции (RR)

```
[7:6] - код операции
[5:4] - регистр назначения (A=00, B=01, C=10, D=11)
[3:2] - регистр источника
[1:0] - 00 (формат RR)
```

### Непосредственные значения (IMM8)

```
[7:6] - код операции
[5:4] - регистр назначения
[3:0] - 01 (формат IMM8)
Следующий байт - значение
```

### Команды с адресом

```
Первый байт - код операции
Следующие 2 байта - адрес (Big Endian)
```

## Ограничения архитектуры

- Адресное пространство: 16 бит (0x0000-0xFFFF)
- Адреса ввода/вывода: 8 бит (0x00-0xFF)
- 4 регистра общего назначения (A, B, C, D)
- Одноуровневые прерывания

## Лицензия

Этот проект распространяется под лицензией MIT. См. файл [LICENSE](LICENSE) для подробной информации.

## Вклад в проект

Приветствуются pull requests. Для крупных изменений, пожалуйста, сначала откройте issue для обсуждения.

## Контакты

Автор: Darkness
TG: @Letmeto
GitHub: [@Teimir](https://github.com/Teimir)
