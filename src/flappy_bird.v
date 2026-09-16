`include "hvsync_generator.v"

/*
 Juego Flappy Bird en Verilog - VERSIÓN CON GRÁFICOS MEJORADOS (Corregido)
*/

module flappy_bird_top(
    input clk,
    input reset,
    input [7:0] switches_p1,
    output hsync,
    output vsync,
    output [2:0] rgb
);

  wire display_on;
  wire [8:0] hpos;
  wire [8:0] vpos;

  // Generador de sincronía VGA
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(reset),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(hpos),
    .vpos(vpos)
  );

  // -------------------------------------------------------------
  // CONSTANTES DEL JUEGO
  // -------------------------------------------------------------
  localparam [8:0] BIRD_X     = 9'd60;   
  localparam [8:0] BIRD_SIZE  = 9'd8;    
  localparam [8:0] PIPE_WIDTH = 9'd24;   
  localparam [8:0] GAP_HEIGHT = 9'd50;   
  localparam [8:0] FLOOR_Y    = 9'd210;  

  localparam [1:0] STATE_START    = 2'd0;
  localparam [1:0] STATE_PLAY     = 2'd1;
  localparam [1:0] STATE_GAMEOVER = 2'd2;

  reg [1:0] state = STATE_START;

  // -------------------------------------------------------------
  // VARIABLES FÍSICAS Y CONTADORES
  // -------------------------------------------------------------
  reg signed [11:0] bird_y_fp = 12'sd1600; 
  reg signed [7:0]  bird_vy   = 8'sd0;     

  reg [8:0] pipe_x = 9'd240;               
  reg [8:0] gap_y  = 9'd70;                

  reg [7:0] rng_counter = 8'd0;
  reg [8:0] ground_scroll = 9'd0;
  reg [8:0] cloud_scroll = 9'd0;

  always @(posedge clk) rng_counter <= rng_counter + 1'b1;

  wire jump_button = switches_p1[0] || switches_p1[2]; 
  reg jump_btn_prev = 1'b0;
  wire jump_pressed = jump_button && !jump_btn_prev;

  wire [8:0] bird_y = {1'b0, bird_y_fp[11:4]};

  // -------------------------------------------------------------
  // LÓGICA Y ESTADOS DEL JUEGO
  // -------------------------------------------------------------
  always @(posedge vsync) begin
    jump_btn_prev <= jump_button;

    // Animación continua del fondo (Parallax)
    if (state == STATE_START || state == STATE_PLAY) begin
      ground_scroll <= ground_scroll + 9'd2;
      cloud_scroll  <= cloud_scroll + 9'd1;
    end

    case (state)
      STATE_START: begin
        bird_y_fp <= 12'sd1600;
        bird_vy   <= 8'sd0;
        pipe_x    <= 9'd240;
        gap_y     <= 9'd70;
        
        if (jump_pressed) state <= STATE_PLAY;
      end

      STATE_PLAY: begin
        bird_vy   <= bird_vy + 8'sd1; // Gravedad
        bird_y_fp <= bird_y_fp + {{4{bird_vy[7]}}, bird_vy};

        if (jump_pressed) bird_vy <= -8'sd32; // Salto

        // Movimiento de tubos
        if (pipe_x <= 9'd2) begin
          pipe_x <= 9'd240; 
          gap_y  <= 9'd30 + {3'b000, rng_counter[5:0]};
        end else begin
          pipe_x <= pipe_x - 9'd2; 
        end

        // Colisiones
        if ((bird_y >= (FLOOR_Y - BIRD_SIZE)) || (bird_y <= 9'd8) || // Suelo/Techo
            ((pipe_x - 9'd2 <= BIRD_X + BIRD_SIZE) && (pipe_x + PIPE_WIDTH + 9'd2 >= BIRD_X) && // X colisión
             (bird_y < gap_y || bird_y + BIRD_SIZE > gap_y + GAP_HEIGHT))) begin // Y colisión
          state <= STATE_GAMEOVER;
        end
      end

      STATE_GAMEOVER: begin
        if (jump_pressed) state <= STATE_START;
      end

      default: state <= STATE_START;
    endcase
  end

  // -------------------------------------------------------------
  // SPRITES (ROMs dibujadas en bits)
  // -------------------------------------------------------------
  // Forma del Pájaro (1=dibujar, 0=transparente)
  reg [7:0] bird_shape [0:7];
  initial begin
    bird_shape[0] = 8'b00011110;
    bird_shape[1] = 8'b00111111;
    bird_shape[2] = 8'b01111111;
    bird_shape[3] = 8'b01111111;
    bird_shape[4] = 8'b01111111;
    bird_shape[5] = 8'b00111111;
    bird_shape[6] = 8'b00011100;
    bird_shape[7] = 8'b00000000;
  end

  // Forma de la nube (8x8 píxeles escalados)
  reg [7:0] cloud_shape [0:7];
  initial begin
    cloud_shape[0] = 8'b00000000;
    cloud_shape[1] = 8'b00011000;
    cloud_shape[2] = 8'b00111100;
    cloud_shape[3] = 8'b01111110;
    cloud_shape[4] = 8'b11111111;
    cloud_shape[5] = 8'b11111111;
    cloud_shape[6] = 8'b00000000;
    cloud_shape[7] = 8'b00000000;
  end

  // -------------------------------------------------------------
  // RENDERIZADO VISUAL
  // -------------------------------------------------------------
  
  // -- 1. PÁJARO --
  wire [8:0] diff_bx = hpos - BIRD_X;
  wire [8:0] diff_by = vpos - bird_y;
  wire [2:0] bx = diff_bx[2:0];
  wire [2:0] by = diff_by[2:0];

  wire bird_gfx = (hpos >= BIRD_X) && (hpos < BIRD_X + BIRD_SIZE) &&
                  (vpos >= bird_y) && (vpos < bird_y + BIRD_SIZE);
  
  wire [7:0] bird_row = bird_shape[by];
  wire bird_pixel = bird_gfx ? bird_row[7 - bx] : 1'b0;
  
  // Detalles del pájaro por coordenadas
  wire is_eye   = (bx >= 3'd5 && bx <= 3'd6) && (by >= 3'd1 && by <= 3'd2);
  wire is_pupil = (bx == 3'd6) && (by == 3'd2);
  wire is_wing  = (bx >= 3'd1 && bx <= 3'd2) && (by >= 3'd3 && by <= 3'd4);
  wire is_beak  = (bx >= 3'd5) && (by >= 3'd4 && by <= 3'd5);

  // -- 2. TUBOS --
  wire in_pipe_x  = (hpos >= pipe_x) && (hpos < pipe_x + PIPE_WIDTH);
  wire in_cap_x   = (hpos >= pipe_x - 9'd2) && (hpos < pipe_x + PIPE_WIDTH + 9'd2);
  
  wire in_gap     = (vpos >= gap_y) && (vpos < gap_y + GAP_HEIGHT);
  wire in_cap_top = (vpos >= gap_y - 9'd8) && (vpos < gap_y);
  wire in_cap_bot = (vpos >= gap_y + GAP_HEIGHT) && (vpos < gap_y + GAP_HEIGHT + 9'd8);
  
  wire pipe_body_gfx = in_pipe_x && !(in_gap || in_cap_top || in_cap_bot) && (vpos < FLOOR_Y);
  wire pipe_cap_gfx  = in_cap_x && (in_cap_top || in_cap_bot);
  wire any_pipe_gfx  = pipe_body_gfx || pipe_cap_gfx;
  
  wire pipe_highlight = (hpos >= pipe_x + 9'd2) && (hpos <= pipe_x + 9'd6);

  // -- 3. NUBES (Parallax) --
  // Nube 1 (Más lenta)
  wire [8:0] cx1_full = hpos + {1'b0, cloud_scroll[8:1]}; 
  wire [2:0] cx1 = cx1_full[4:2]; 
  wire [8:0] cloud1_vpos = vpos - 9'd20;  
  wire [2:0] cy1 = cloud1_vpos[4:2];
  wire cloud1_bbox = (vpos >= 9'd20) && (vpos < 9'd52) && (cx1_full[6:5] == 2'b00);
  wire [7:0] cloud1_row = cloud_shape[cy1];
  wire cloud1_pixel = cloud1_bbox ? cloud1_row[7 - cx1] : 1'b0;

  // Nube 2 (Más rápida y baja)
  wire [8:0] cx2_full = hpos + cloud_scroll; 
  wire [2:0] cx2 = cx2_full[4:2];
  wire [8:0] cloud2_vpos = vpos - 9'd70;  
  wire [2:0] cy2 = cloud2_vpos[4:2];
  wire cloud2_bbox = (vpos >= 9'd70) && (vpos < 9'd102) && (cx2_full[7:6] == 2'b01);
  wire [7:0] cloud2_row = cloud_shape[cy2];
  wire cloud2_pixel = cloud2_bbox ? cloud2_row[7 - cx2] : 1'b0;

  wire any_cloud = cloud1_pixel || cloud2_pixel;

  // -- 4. SUELO --
  wire floor_gfx = (vpos >= FLOOR_Y);
  wire floor_top = (vpos >= FLOOR_Y) && (vpos < FLOOR_Y + 9'd4);
  wire ground_pattern = ((hpos + ground_scroll) & 9'd16) != 9'd0;

  // -------------------------------------------------------------
  // MEZCLADOR DE COLORES RGB FINAL
  // -------------------------------------------------------------
  reg [2:0] pixel_color;
  always @(*) begin
    if (!display_on) begin
      pixel_color = 3'b000;
    end 
    else if (bird_pixel) begin
      if (is_pupil)       pixel_color = 3'b000;
      else if (is_eye)    pixel_color = 3'b111;
      else if (is_wing)   pixel_color = 3'b111;
      else if (is_beak)   pixel_color = 3'b001;
      else                pixel_color = 3'b011;
    end 
    else if (any_pipe_gfx) begin
      pixel_color = pipe_highlight ? 3'b011 : 3'b010;
    end 
    else if (floor_gfx) begin
      pixel_color = floor_top ? 3'b010 : (ground_pattern ? 3'b011 : 3'b001);
    end 
    else if (any_cloud) begin
      pixel_color = 3'b111;
    end 
    else begin
      pixel_color = (state == STATE_GAMEOVER) ? 3'b000 : 3'b110;
    end
  end

  assign rgb = pixel_color;

endmodule