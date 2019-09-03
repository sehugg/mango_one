
`include "hvsync_generator.v"
`include "cpu6502.v"
`include "font_cp437_8x8.v"

/**
Mango One

A 6502 computer inspired by Steve Wozniak's Apple I design

Memory map:

$0000	$0FFF	RAM
$A000	$CFFF	Expansion ROM
$D010	$D013	6821 PIA (keyboard, terminal)
$E000	$EFFF	Integer BASIC
$FF00	$FFFF	Woz Monitor, CPU vectors

$D010	Read ASCII character from keyboard.
        If high bit is set then a key has been pressed.
        
$D011	Writing to this address clears the high bit of $D010.
        The CPU usually does this after reading a key.
        
$D012	Writes a character to the terminal.
        On read, if high bit is set then the display
        is not ready to receive characters.

MangoMon commands:

R aaaa    - dump memory at $aaaa
Enter     - dump next 8 bytes
W aaaa bb - write memory $bb at $aaaa
G aaaa    - jump to address $aaaa

https://www.applefritter.com/replica/chapter7
https://github.com/mamedev/mame/blob/master/src/mame/drivers/apple1.cpp
https://github.com/jefftranter/6502/blob/master/asm/wozmon/wozmon.s
https://www.applefritter.com/files/signetics2513.pdf
http://retro.hansotten.nl/uploads/6502docs/signetics2504.pdf
http://retro.hansotten.nl/uploads/6502docs/signetics2519.pdf
*/

module signetics_term(clk, reset, hpos, vpos, tready, dot, te, ti);

  input clk,reset;
  input [8:0] hpos;
  input [8:0] vpos;
  input te;		// input enable
  input [7:0] ti;	// input data
  output tready;	// terminal ready
  output dot;		// terminal video output
  
  reg [7:0] dshift[1024]; // frame buffer offset
  reg [9:0] dofs;	// current offset to write
  reg [9:0] scroll;	// scroll offset
  reg [9:0] scnt;	// row clear counter when scrolling

  always @(posedge clk or posedge reset)
    if (reset) begin
      scnt <= 0;
      scroll <= 0;
      dofs <= 28*32;
      scroll <= 0;
    end else if (scnt > 0) begin
      dshift[scroll] <= 0; // clear row when scrolling
      scroll <= scroll + 1;
      scnt <= scnt - 1;
    end else if (te) begin
      if (ti == 13) begin // CR, next row
        scnt <= 32;
        dofs <= ((dofs + 32) & ~31);
      end else if (ti >= 32) begin // display char
        dshift[dofs] <= ti;
        if ((dofs & 31) == 31) scnt <= 32; // wrap around
        dofs <= dofs + 1;
      end
    end

  // character generator from ROM
  font_cp437_8x8 tile_rom(
    .addr(char_addr),
    .data(char_data)
  );
  wire [9:0] nt_addr = {vpos[7:3], hpos[7:3]};
  wire [7:0] cur_char = dshift[nt_addr + scroll];
  wire [10:0] char_addr = {cur_char, vpos[2:0]};
  wire [7:0] char_data;
  wire dot = char_data[~hpos[2:0]]; // video output
  
  // terminal ready output
  // only possible at end of line, if not scrolling
  assign tready = !reset && !te && scnt == 0 && hpos == 256;
  
  initial begin
    integer i;
    for (i=0; i<1024; i=i+1) dshift[i] = 0; // clear buffer
  end
  
endmodule

module apple1_top(clk, reset, hsync, vsync, rgb, keycode, keystrobe);

  input clk, reset;
  input [7:0] keycode;
  output reg keystrobe;
  output hsync, vsync;
  output [2:0] rgb;
  wire display_on;
  wire [8:0] hpos;
  wire [8:0] vpos;

  wire [15:0] AB;   	// address bus
  wire [7:0] DI;        // data in, read bus
  wire [7:0] DO;        // data out, write bus
  wire WE;              // write enable
  wire IRQ=0;           // interrupt request
  wire NMI=0;           // non-maskable interrupt request
  wire RDY=1;           // Ready signal. Pauses CPU when RDY=0 

  cpu6502 cpu( clk, reset, AB, DI, DO, WE, IRQ, NMI, RDY );

  always @(posedge clk)
    begin
      casez (AB)
        16'h0zzz: DI <= ram[AB[11:0]];
        16'hd010: begin
          if (keycode >= 97+128 && keycode <= 122+128)
            DI <= keycode - 32; // convert to uppercase
          else
            DI <= keycode; // keyboard data
          keystrobe <= (keycode & 8'h80) != 0; // clear kbd buffer
        end
        16'hd011: begin
          DI <= keycode & 8'h80; // keyboard status
          keystrobe <= 0;
        end
        16'hd012: begin
          DI <= {!tready, 7'b0}; // display status
        end
        16'hffzz: DI <= monitor_rom[AB[7:0]];
      endcase
    end

  always @(posedge clk)
    if (WE) begin
      casez (AB)
        16'hd010: begin end // 
        16'hd011: begin end // 
        16'hd012: begin end // handled by terminal module
        16'hd013: begin end // 
        16'h0zzz: ram[AB[11:0]] <= DO; // write RAM
      endcase
    end

  reg [7:0] ram[4096];		// 1K of RAM
  reg [7:0] monitor_rom[256];	// WozMon ROM

  initial begin
    $readmemh("mango1.hex", monitor_rom);
  end
  
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(reset),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(hpos),
    .vpos(vpos)
  );

  wire tready; // terminal ready
  wire dot; // dot output
  wire te = WE && AB == 16'hd012; // terminal enable (write)
  signetics_term terminal(clk, reset, hpos, vpos,
                          tready, dot,
                          te, .ti(DO & 8'h7f));
  
  wire r = display_on && 0;
  wire g = display_on && dot;
  wire b = display_on && 0;
  assign rgb = {b,g,r};

endmodule
