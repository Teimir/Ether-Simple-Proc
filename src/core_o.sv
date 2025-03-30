module core(
  input clk_i,
  input rst_i,
  //Работа с внешними устройствами
  input irq_i,          // Сигнал прерывания
  input [7:0] io_data_i,// Данные от устройств ввода
  output [7:0] io_data_o,// Данные для устройств вывода
  output [7:0] io_addr_o,// Адрес устройства ввода/вывода
  output io_we_o,       // Сигнал записи в устройство вывода
  // A\D line
  output [15:0] address_o,  
  input [7:0] data_i,
  output we_i,              
  output [7:0] data_o
);

  // Состояния конечного автомата
  localparam IDLE_S     = 5'b0;
  localparam FETCH_S    = 5'b1;
  localparam FETCH2_S   = 5'd2;
  localparam FETCH3_S   = 5'd3;
  localparam EXEC_S     = 5'd4;
  localparam WRBK_S     = 5'd5;
  localparam INT_SAVE_S = 5'd6;  // Сохранение состояния при прерывании
  localparam INT_JUMP_S = 5'd7;  // Переход к обработчику

  // Определение битов флагов
  localparam FLAG_Z     = 0; // Zero
  localparam FLAG_C     = 1; // Carry
  localparam FLAG_V     = 2; // Overflow
  localparam FLAG_S     = 3; // Sign
  localparam FLAG_IF    = 4; // Interrupt Flag

  // Адрес вектора прерываний
  localparam IVT_ADDR   = 16'hFFFE;

  reg  [4:0] state;
  reg  [4:0] next_state;
  reg        stop;
  reg        int_pending;     // Флаг ожидания прерывания
  reg [15:0] int_save_pc;     // Сохраненный PC при прерывании
  reg  [7:0] int_save_flags;  // Сохраненные флаги при прерывании

  // Регистры процессора
  reg  [7:0] instruction;
  reg  [7:0] instruction_2nd_byte;
  reg  [7:0] instruction_3rd_byte;
  reg  [7:0] RF [4];  // Регистровый файл (A=0, B=1, C=2, D=3)
  reg [15:0] PC;
  wire[15:0] next_PC;
  reg  [7:0] flags;
  reg  [7:0] writeback_reg;

  wire [1:0] onebyte_r1 = instruction[3:2];
  wire [1:0] onebyte_r2 = instruction[1:0];
  wire [7:0] alu_result;
  wire [8:0] alu_result_ext; // 9 бит для учета переноса

  // Остановка процессора
  always_ff @(posedge clk_i) begin
    if (rst_i) stop <= '0;
    else if (instruction == 8'hEF) stop <= '1; 
  end

  // Обработка запросов прерываний
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      int_pending <= 1'b0;
    end else if (irq_i && flags[FLAG_IF] && !stop && !int_pending) begin
      int_pending <= 1'b1;
    end else if (state == INT_JUMP_S) begin
      int_pending <= 1'b0;
    end
  end

  // Указатель инструкции
  always_ff @(posedge clk_i) begin
    if (rst_i) PC <= '0;
    else PC <= next_PC;
  end

  // Логика следующего PC
  always_comb begin
    case(state)
      FETCH_S, FETCH2_S, FETCH3_S: next_PC = PC + 16'd1; 
      EXEC_S: begin
        if (instruction[7:4] == 4'hD) begin // JMP/JZ/JC
          case(instruction[3:0])
            4'd0: next_PC = {instruction_2nd_byte, instruction_3rd_byte}; // JMP
            4'd1: next_PC = flags[FLAG_Z] ? {instruction_2nd_byte, instruction_3rd_byte} : PC; // JZ
            4'd2: next_PC = flags[FLAG_C] ? {instruction_2nd_byte, instruction_3rd_byte} : PC; // JC
            default: next_PC = PC;
          endcase
        end
        else if (instruction == 8'hE1) begin // RETI
          next_PC = int_save_pc; // Восстанавливаем сохраненный PC
        end
        else next_PC = PC;
      end
      INT_JUMP_S: next_PC = {data_i, instruction_2nd_byte}; // Адрес обработчика из IVT
      default: next_PC = PC;
    endcase
  end

  // Определение адреса для памяти
  always_comb begin
    address_o = PC; // По умолчанию - адрес следующей инструкции
    
    case (state)
      EXEC_S: begin
        case (instruction[7:4])
          4'h9: address_o = {instruction_2nd_byte, instruction_3rd_byte}; // MOV [ADDR], R
          4'hA: address_o = {instruction_2nd_byte, instruction_3rd_byte}; // MOV R, [ADDR]
        endcase
      end
      INT_JUMP_S: address_o = IVT_ADDR; // Чтение вектора прерываний
      default: address_o = PC;
    endcase
  end

  // Конечный автомат
  always_ff @(posedge clk_i) begin
    if (rst_i) state <= IDLE_S;
    else state <= next_state;
  end

  always_comb begin
    next_state = IDLE_S;
    case (state)
      IDLE_S: if (!stop) next_state = int_pending ? INT_SAVE_S : FETCH_S;
      
      FETCH_S: begin
        case (instruction[7:4])
          4'h0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'hA: next_state = EXEC_S;
          4'h7, 4'h8, 4'hB, 4'hC, 4'hD: next_state = FETCH2_S;
          4'h9: next_state = FETCH2_S;
          4'hE, 4'hF: next_state = EXEC_S;
        endcase
      end
      
      FETCH2_S: begin
        case (instruction[7:4])
          4'h7, 4'h8, 4'hB, 4'hC: next_state = EXEC_S;
          4'h9, 4'hD: next_state = FETCH3_S;
        endcase
      end
      
      FETCH3_S: next_state = EXEC_S;
      EXEC_S: next_state = WRBK_S;
      WRBK_S: next_state = int_pending ? INT_SAVE_S : IDLE_S;
      
      // Обработка прерываний
      INT_SAVE_S: next_state = INT_JUMP_S;
      INT_JUMP_S: next_state = FETCH_S;
    endcase
  end

  // Реализация IN/OUT
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      io_data_o <= 8'b0;
      io_addr_o <= 8'b0;
      io_we_o <= 1'b0;
    end
    else if (state == EXEC_S) begin
      case (instruction[7:4])
        4'hB: begin // IN
          io_addr_o <= instruction_2nd_byte;
          io_we_o <= 1'b0;
          writeback_reg <= io_data_i; // Сохраняем данные из порта
        end
        4'hC: begin // OUT
          io_addr_o <= instruction_2nd_byte;
          io_data_o <= RF[onebyte_r1];
          io_we_o <= 1'b1;
        end
        default: begin
          io_we_o <= 1'b0;
        end
      endcase
    end
    else begin
      io_we_o <= 1'b0;
    end
  end

  // Считывание инструкций
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      instruction <= '0;
      instruction_2nd_byte <= '0;
      instruction_3rd_byte <= '0;
    end
    else begin
      case (state)
        FETCH_S: instruction <= data_i;
        FETCH2_S: instruction_2nd_byte <= data_i;
        FETCH3_S: instruction_3rd_byte <= data_i;
      endcase
    end
  end

  // Арифметико-логическое устройство
  always_comb begin
    alu_result_ext = 9'b0;
    case (instruction[7:4])
      4'h1: alu_result_ext = RF[onebyte_r1]; // MOV R2R
      4'h2: alu_result_ext = RF[onebyte_r1] + RF[onebyte_r2]; // ADD
      4'h3: alu_result_ext = RF[onebyte_r1] - RF[onebyte_r2]; // SUB
      4'h4: alu_result_ext = RF[onebyte_r1] & RF[onebyte_r2]; // AND
      4'h5: alu_result_ext = RF[onebyte_r1] | RF[onebyte_r2]; // OR
      4'h6: alu_result_ext = RF[onebyte_r1] ^ RF[onebyte_r2]; // XOR
      4'h7: alu_result_ext = instruction_2nd_byte; // MOV IMM
      4'h8: alu_result_ext = RF[onebyte_r1] + instruction_2nd_byte; // ADD IMM
      default: alu_result_ext = 9'b0;
    endcase
  end

  assign alu_result = alu_result_ext[7:0];

  // Установка флагов
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      flags <= 8'b0;
    end
    else if (state == EXEC_S) begin
      case (instruction[7:4])
        4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h8: begin
          // Флаг Zero
          flags[FLAG_Z] <= (alu_result == 8'b0);
          
          // Флаг Carry/Заем
          flags[FLAG_C] <= alu_result_ext[8];
          
          // Флаг Overflow
          if (instruction[7:4] == 4'h2) // ADD
            flags[FLAG_V] <= (RF[onebyte_r1][7] == RF[onebyte_r2][7]) && 
                            (alu_result[7] != RF[onebyte_r1][7]);
          else if (instruction[7:4] == 4'h3) // SUB
            flags[FLAG_V] <= (RF[onebyte_r1][7] != RF[onebyte_r2][7]) && 
                            (alu_result[7] != RF[onebyte_r1][7]);
          else
            flags[FLAG_V] <= 1'b0;
            
          // Флаг Sign
          flags[FLAG_S] <= alu_result[7];
        end
        
        // Обработка команд прерываний
        4'hE: begin
          case (instruction[3:0])
            4'h0: flags[FLAG_IF] <= 1'b1; // EI
            4'h1: flags[FLAG_IF] <= 1'b0; // DI
          endcase
        end
      endcase
    end
    else if (state == INT_SAVE_S) begin
      flags[FLAG_IF] <= 1'b0; // Запрещаем прерывания при входе в обработчик
    end
    else if (instruction == 8'hE1 && state == EXEC_S) begin // RETI
      flags <= int_save_flags; // Восстанавливаем флаги
      flags[FLAG_IF] <= 1'b1;  // И разрешаем прерывания
    end
  end

  // Обработка прерываний (без стека)
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      int_save_pc <= 16'b0;
      int_save_flags <= 8'b0;
    end
    else if (state == FETCH_S && int_pending) begin
      int_save_pc <= PC;         // Сохраняем текущий PC
      int_save_flags <= flags;   // Сохраняем текущие флаги
    end
  end

  // Регистр Writeback и запись в регистровый файл
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      writeback_reg <= 8'd0;
      for (int i = 0; i < 4; i++) RF[i] <= 8'b0;
    end
    else begin
      if (state == EXEC_S) begin
        case (instruction[7:4])
          4'h1, 4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7, 4'h8, 4'hB: 
            writeback_reg <= alu_result;
        endcase
      end
      
      if (state == WRBK_S) begin
        case (instruction[7:4])
          4'h1: RF[onebyte_r2] <= writeback_reg; // MOV R2R
          4'h2, 4'h3, 4'h4, 4'h5, 4'h6: RF[onebyte_r1] <= writeback_reg; // ALU ops
          4'h7: RF[onebyte_r1] <= writeback_reg; // MOV IMM
          4'h8: RF[onebyte_r1] <= writeback_reg; // ADD IMM
          4'hB: RF[onebyte_r1] <= writeback_reg; // IN
          4'hA: RF[onebyte_r1] <= data_i; // MOV R, [ADDR]
        endcase
      end
    end
  end

  // Управление записью в память
  assign we_i = (state == EXEC_S && instruction[7:4] == 4'h9);
  assign data_o = (state == EXEC_S && instruction[7:4] == 4'h9) ? RF[onebyte_r1] : 8'b0;

endmodule