module core(
  input clk_i,
  input rst_i,
  // Работа с внешними устройствами
  input irq_i,          // Сигнал прерывания
  input [7:0] io_data_i,// Данные от устройств ввода
  output reg [7:0] io_data_o,// Данные для устройств вывода
  output reg [7:0] io_addr_o,// Адрес устройства ввода/вывода
  output reg io_we_o,   // Сигнал записи в устройство вывода
  // Интерфейс памяти
  output reg [15:0] address_o,  
  input [7:0] data_i,
  output reg we_i,              
  output reg [7:0] data_o
);

  // Состояния конечного автомата
  localparam IDLE_S     = 4'd0;
  localparam FETCH_S    = 4'd1;
  localparam DECODE_S   = 4'd2;
  localparam FETCH2_S   = 4'd3;
  localparam FETCH3_S   = 4'd4;
  localparam EXEC_S     = 4'd5;
  localparam MEM_S      = 4'd6;
  localparam WB_S       = 4'd7;
  localparam HALT_S     = 4'd13; // Состояние останова
  localparam V_S        = 4'd14;
  localparam V2_S = 4'd12;
  localparam INT_SAVE1_S = 4'd8; // Сохранение PC младший байт
  localparam INT_SAVE2_S = 4'd9; // Сохранение PC старший байт
  localparam INT_SAVE3_S = 4'd10; // Сохранение флагов
  localparam INT_JUMP_S = 4'd11;  // Переход к обработчику

  // Определение битов флагов
  localparam FLAG_Z     = 0; // Zero
  localparam FLAG_C     = 1; // Carry
  localparam FLAG_V     = 2; // Overflow
  localparam FLAG_S     = 3; // Sign
  localparam FLAG_IF    = 4; // Interrupt Flag

  // Адрес вектора прерываний
  localparam IVT_ADDR   = 16'hFFFE;

  // Регистры процессора
  reg [3:0] state;
  reg [7:0] RF [0:3];  // Регистровый файл (A=0, B=1, C=2, D=3)
  reg [15:0] PC;       // Счетчик команд
  reg [7:0] flags;     // Регистр флагов
  
  // Регистры для хранения инструкций
  reg [7:0] instruction;
  reg [7:0] instruction_2nd_byte;
  reg [7:0] instruction_3rd_byte;
  
  // Временные регистры
  reg [7:0] alu_result;
  reg [8:0] alu_result_ext; // 9 бит для учета переноса

  reg [15:0] int_save_pc;
  reg [7:0] int_save_flags;   
  reg int_pending;          // Флаг ожидания прерывания
  reg irq_i_past;
  // Комбинационные сигналы
  wire [3:0] opcode = instruction[7:4];
  wire [1:0] reg1 = instruction[3:2];
  wire [1:0] reg2 = instruction[1:0];
  wire [7:0] imm8 = instruction_2nd_byte;
  wire [15:0] addr16 = {instruction_2nd_byte, instruction_3rd_byte};
   // Останов процессора
  reg halt;


  always_ff @(posedge clk_i) begin
     irq_i_past <= irq_i;
	  if (rst_i) irq_i_past <= 1'b0;
  end

  // Логика следующего состояния
  always @(posedge clk_i) begin
    if (rst_i) begin
      state <= IDLE_S;
      PC <= 16'h0000;
      flags <= 8'b00000000;
      we_i <= 1'b0;
      io_we_o <= 1'b0;
      RF[0] <= '0;
      RF[1] <= '0;
      RF[2] <= '0;
      RF[3] <= '0;
    end else begin
      case (state)
        IDLE_S: begin
          if (!halt) state <= FETCH_S;
        end
        
        FETCH_S: begin
          instruction <= data_i;
          state <= DECODE_S;
        end
        
        DECODE_S: begin
          case (opcode)
            // 2-байтовые команды
            4'h7, 4'h8, 4'hB, 4'hC: begin
              PC <= PC + 1;
              state <= V_S;
              
            end
            // 3-байтовые команды
            4'h9, 4'hA, 4'hD: begin
              PC <= PC + 1;
              state <= V_S;
            end
            // 1-байтовые команды
            default: state <= EXEC_S;
          endcase
        end
        
        V_S: state <= FETCH2_S;

        FETCH2_S: begin
          instruction_2nd_byte <= data_i;
          case (opcode)
            // 3-байтовые команды
            4'h9, 4'hA, 4'hD: begin
              PC <= PC + 1;
              state <= V2_S;
            end
            // 2-байтовые команды
            default: state <= EXEC_S;
          endcase
        end
        
        V2_S: state <= FETCH3_S;

        FETCH3_S: begin
          instruction_3rd_byte <= data_i;
          state <= EXEC_S;
        end
        
        EXEC_S: begin
          // Выполнение операции
          case (opcode)
            // MOV R1, R2
            4'h1: alu_result <= RF[reg2];
            
            // ADD R1, R2
            4'h2: alu_result_ext <= RF[reg1] + RF[reg2];
            
            // SUB R1, R2
            4'h3: alu_result_ext <= RF[reg1] - RF[reg2];
            
            // AND R1, R2
            4'h4: alu_result <= RF[reg1] & RF[reg2];
            
            // OR R1, R2
            4'h5: alu_result <= RF[reg1] | RF[reg2];
            
            // XOR R1, R2
            4'h6: alu_result <= RF[reg1] ^ RF[reg2];
            
            // MOV R, IMM8 | MOV R, R+R
            4'h7: begin 
              if(!instruction[2]) alu_result <= imm8;
              else alu_result <= {RF[imm8[3:2]], RF[imm8[1:0]]};
              if ({instruction[7:2], 2'b00} == 8'h74) we_i <= 1'b1;
            end
            // ADD R, IMM8
            4'h8: alu_result_ext <= RF[reg1] + imm8;
            
            // MOV [ADDR16], R
            4'h9: begin
              //address_o <= addr16;
              data_o <= RF[reg2];
              we_i <= 1'b1;
            end
            
            // MOV R, [ADDR16]
            4'hA: begin
              //address_o <= addr16;
            end
            
            // IN R, PORT8
            4'hB: begin
              io_addr_o <= imm8;
              io_we_o <= 1'b0;
            end
            
            // OUT PORT8, R
            4'hC: begin
              io_addr_o <= imm8;
              io_data_o <= RF[reg1];
              io_we_o <= 1'b1;
            end
            
            // JMP/JZ/JC ADDR16
            4'hD: begin
              case (instruction[3:0])
                4'd0: PC <= addr16; // JMP
                4'd1: if (flags[FLAG_Z]) PC <= addr16; // JZ
                4'd2: if (flags[FLAG_C]) PC <= addr16; // JC
              endcase
            end
            
            // EI/DI
            4'hE: begin
              case (instruction[3:0])
                4'h1: begin
                  flags <= int_save_flags;
                  PC <= int_save_pc;
                  state <= IDLE_S;
                end
                4'h2: flags[FLAG_IF] <= 1'b1; // EI
                4'h3: flags[FLAG_IF] <= 1'b0; // DI
                4'hF: begin /* HALT - обрабатывается отдельно */ end
              endcase
            end
          endcase
          
          // Переход в следующее состояние
          if (opcode == 4'h9 || opcode == 4'hA || opcode == 4'hB || opcode == 4'hC || {instruction[7:2], 2'b00} == 8'h74) begin
            state <= MEM_S;
          end else begin
            state <= WB_S;
          end
        end
        
        MEM_S: begin
          we_i <= 1'b0;
          io_we_o <= 1'b0;
          state <= WB_S;
        end
        
        WB_S: begin
          case (opcode)
            // MOV R1, R2
            4'h1: RF[reg1] <= alu_result;
            
            // ADD R1, R2
            4'h2: begin
              RF[reg1] <= alu_result_ext[7:0];
              flags[FLAG_Z] <= (alu_result_ext[7:0] == 8'b0);
              flags[FLAG_C] <= alu_result_ext[8];
              flags[FLAG_V] <= (RF[reg1][7] == RF[reg2][7]) && 
                              (alu_result_ext[7] != RF[reg1][7]);
              flags[FLAG_S] <= alu_result_ext[7];
            end
            
            // SUB R1, R2
            4'h3: begin
              RF[reg1] <= alu_result_ext[7:0];
              flags[FLAG_Z] <= (alu_result_ext[7:0] == 8'b0);
              flags[FLAG_C] <= alu_result_ext[8];
              flags[FLAG_V] <= (RF[reg1][7] != RF[reg2][7]) && 
                              (alu_result_ext[7] != RF[reg1][7]);
              flags[FLAG_S] <= alu_result_ext[7];
            end
            
            // AND/OR/XOR R1, R2
            4'h4, 4'h5, 4'h6: begin
              RF[reg1] <= alu_result;
              flags[FLAG_Z] <= (alu_result == 8'b0);
              flags[FLAG_S] <= alu_result[7];
              flags[FLAG_C] <= 1'b0;
              flags[FLAG_V] <= 1'b0;
            end
            
            // MOV R, IMM8 | R, R+R
            4'h7: begin 
              if (!instruction[3]) RF[reg2] <= alu_result; 
            end
            
            // ADD R, IMM8
            4'h8: begin
              RF[reg1] <= alu_result_ext[7:0];
              flags[FLAG_Z] <= (alu_result_ext[7:0] == 8'b0);
              flags[FLAG_C] <= alu_result_ext[8];
              flags[FLAG_V] <= (RF[reg1][7] == imm8[7]) && 
                              (alu_result_ext[7] != RF[reg1][7]);
              flags[FLAG_S] <= alu_result_ext[7];
            end
            
            // MOV R, [ADDR16]
            4'hA: RF[reg2] <= data_i;
            
            // IN R, PORT8
            4'hB: RF[reg1] <= io_data_i;
          endcase
          
          // Обновление PC для всех команд кроме JMP/JZ/JC
          if (opcode != 4'hD) begin
            PC <= PC + 1;
          end
          
          // Проверяем, есть ли ожидающее прерывание
          if (int_pending & flags[FLAG_IF]) begin
            state <= INT_SAVE1_S;
          end else begin
            state <= IDLE_S;
          end
        end
        
        // Сохранение младшего байта PC
        INT_SAVE1_S: begin
          int_save_pc <= PC;
          int_save_flags <= flags;
          state <= INT_SAVE2_S;
        end
        
        // Сохранение старшего байта PC
        INT_SAVE2_S: begin
          PC <= data_i;
          state <= INT_SAVE3_S;
        end
        
        // Сохранение флагов
        INT_SAVE3_S: begin
          PC[15:8] <= data_i; // Читаем адрес обработчика
          state <= IDLE_S;
        end
        
        HALT_S: begin
          // Останов процессора
          if (irq_i && flags[FLAG_IF]) begin
            state <= INT_SAVE1_S;
          end
        end
      endcase
    end
  end

  // Логика прерываний
  always @(posedge clk_i) begin
    if (rst_i) begin
      int_pending <= 1'b0;
    end else if (irq_i_past == 1'b0 && irq_i == 1'b1)begin
      // Запоминаем запрос прерывания, если он разрешен
      int_pending <= 1'b1;
    end else if (state == INT_JUMP_S) begin
      // Сбрасываем флаг после перехода к обработчику
      int_pending <= 1'b0;
    end
  end


 
  always @(posedge clk_i) begin
    if (rst_i) begin
      halt <= 1'b0;
    end else if (state == EXEC_S && opcode == 4'hE && instruction[3:0] == 4'hF) begin
      halt <= 1'b1;
    end
  end

  // Управление адресом памяти
  always_comb begin
  address_o = PC;
    case (state)
      V_S, V2_S, FETCH_S, FETCH2_S, FETCH3_S: address_o = PC;
      EXEC_S: begin
        case (opcode)
          4'h9, 4'hA: address_o = addr16; // Для операций с памятью
          default: address_o = PC;
        endcase
      end
      MEM_S: begin
      case (opcode)
          4'h9:  address_o = addr16;
          4'hA: address_o = addr16; // Для операций с памятью
          default: address_o = PC;
        endcase
      end
      INT_SAVE1_S, INT_JUMP_S: address_o = IVT_ADDR;
      INT_SAVE2_S, INT_SAVE3_S: address_o = IVT_ADDR + 16'b1;
      default: address_o = PC;
    endcase
  end
endmodule