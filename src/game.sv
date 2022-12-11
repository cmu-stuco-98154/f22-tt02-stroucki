// Michael Stroucken
// 98-154
// Tinytapeout Corral project

`default_nettype none

module game
  (input logic clock,
  input logic reset_n,
  input logic enter,
  input logic [2:0] move,
  output logic [3:0] cowboypos,
  output logic [3:0]  horsepos,
  output logic gameover,
  output logic lostwon,
  output logic ready);
  
  typedef enum logic [2:0] {IDLE, SETUP, KICK, WAIT, GAME} state_t;
  state_t state = SETUP, nextState;

  logic [3:0] horsepos;
  logic [3:0] cowboypos;

  logic gameenter, gamegameover, gamelostwon, gameready;
  logic [2:0] gamemove;


  logic reset_n;
  assign reset_n =  !reset;

  // need random numbers 0 to 9,
  // 3 bits + 2 bits?
  logic [4:0] lfsrout;
  lfsr #(5) lfsrinstance(.i_Clk(clock), .i_Enable(1'b0),
    .o_LFSR_Data(lfsrout));

  logic [3:0] p[10] = { 4'd0, 4'd1, 4'd2, 4'd3, 4'd3, 4'd2, 4'd2, 4'd1, 4'd0, 4'd-1 };
  logic [3:0] q[10] = { 4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd4, 4'd3, 4'd2, 4'd1, 4'd0 };

  logic [3:0] pVal, qVal;
  logic [4:0] randomVal;

  //sequential
  // arena limited to 16
  logic [2:0] kickflight, kickcount, cowboyHitpoints
/*
  register #(4) cowboyposreg(.clock(clock), .reset_n(reset_n),
    .ld_n(loadCowboypos_n), .cl_n(1'b1), .in(targetCowboypos),
    .out(cowboypos));
  register #(4) horseposreg(.clock(clock), .reset_n(reset_n),
    .ld_n(loadHorsepos_n), .cl_n(1'b1), .in(targetHorsepos),
    .out(cowboypos));
  register #(3) kickflightreg(.clock(clock), .reset_n(reset_n),
    .ld_n(loadKickflight_n), .cl_n(1'b1), .in(targetKickflight),
    .out(kickflight));
  register #(4) cowboyhitpointsreg(.clock(clock), .reset_n(reset_n),
    .ld_n(loadHitpoints_n), .cl_n(1'b1), .in(targetHitpoints),
    .out(cowboyHitpoints));
*/

  // logic lostwon, gameover
  // not counting rounds
  logic kickdead;
  logic [3:0] distance;
  logic coyboyLeftOfHorse;
  

  // set up random values
  assign randomval = lfsrout[4:2] + lfsrout[1:0];
  assign pVal = p[randomval];
  assign qVal = q[randomval];

  function automatic integer cowboyDest;
    input cowboyLeftOfHorse;
    input [3:0] cowboyPos;
    input [3:0] move;
    cowboyDest = cowboyPos + (cowboyLeftOfHorse? move : - move);
  endfunction

  function automatic cowboyInBound;
    input cowboyLeftOfHorse;
    input [3:0] cowboyPos;
    input [3:0] move;
    integer dest = cowboyDest(cowboyLeftOfHorse, cowboyPos, move);
    if (dest > 0 && dest < 16) return 1;
    return 0;
  endfunction

  function automatic boundHorse;
    integer horsePos;
    integer targetHorsePos;
    targetHorsePos = horsePos;
    if (horsePos < 0) targetHorsePos = 0;
    if (horsePos > (16 - 1)) targetHorsePos = (16 - 1);
    boundHorse = targetHorsePos;
  endfunction

  always_comb begin
    targetGameover = gameover;
    targetKickflight = kickflight;
    targetKickcount = kickcount;
    targetCowboypos = cowboypos;
    targetHorsepos = horsepos;
    targetLostwon = lostwon;
    targetMove = move;
    targetReady = 0;
    kickdead = (kickcount > cowboyHitpoints);
    // used for game decision, so should be next values
    distance = (targetCowboypos > targetHorsepos) ? targetCowboypos - targetHorsepos : targetHorsepos - targetCowboypos;
    cowboyLeftOfHorse = (cowboypos > horsepos) ? 0 : 1;
// IDLE, SETUP, KICK, WAIT, GAME
    unique case (state)
      IDLE: if (enter && move > 3'd0 && move < 3'd6 && cowboyInBound(cowboyLeftOfHorse, cowboyPos, move))
        begin
          nextState = GAME;
        end
        else begin
          nextState = IDLE;
          targetReady = 1;
        end
      SETUP: nextState = IDLE;
      WAIT: if (enter) begin
          nextState = WAIT;
        end else nextState = IDLE;
        end
      KICK: if (kickdead)
        begin
          targetGameover = 1;
          targetLostwon = 0;
          nextState = SETUP;
        end
        else begin
           targetKickflight = kickflight - 1;
           nextState = KICK;
           if (targetKickflight == 0) nextState = IDLE;
           if (cowboyLeftOfHorse) begin
             targetHorsepos = boundHorse(horsePos + pVal + 1);
           end else begin
             targetHorsepos = boundHorse(horsePos - pVal - 1);
           end
        end
      GAME: begin
        targetCowboypos = cowboyDest(cowboyLeftOfHorse, cowboyPos, move);
        targetHorsepos = boundHorse(horsepos + (cowboyLeftOfHorse ? pVal : -pVal);
	if (distance < (move << 1) && distance > 1) begin
          // bolt
          // was 9 + 2*pVal
          integer boltStrength = 4'd5 + (pVal << 1);
          targetHorsePos = boundHorse(horsePos + (cowboyLeftOfHorse ? (pVal + 1) : -(pVal + 1)));
          nextState = WAIT;
        end
        // somewhat strange conditioning around this
        else if (distance > 4'd2) begin
          nextState = WAIT;
        end
        else if (randomVal > 5'd3) begin
          if (targetHorsepos == targetCowboypos) begin
            targetGameover = 1;
            targetLostwon = 1;
            nextState = SETUP;
          end
          else nextState = WAIT;
        end
        else begin
          targetKickflight = pVal + 3'd2;
          targetKickcount++;
          targetHorsepos = boundHorse(horsePos - (cowboyLeftOfHorse ? 5 : -5));
          nextState = KICK;

        end
      endcase
    end

       
        

  // state transition  
  always @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      lostwon <= 1;
    end
    if (~reset_n || state == SETUP) begin
      state <= WAIT;
      gameover <= 1;
      cowboypos <= 4'd0;
      kickflight <= 3'd0;
      kickcount <= 3'd0;
      cowboyHitpoints <= 3'd2 + pVal;
      // was 13
      horsepos <= 4'd10 + (randomval > 5 ? qVal : -qVal);
    end
    else begin
      state <= nextState;
      gameover <= targetGameover;
      kickflight <= targetKickflight;
      kickcount <= targetKickcount;
      cowboypos <= targetCowboypos;
      horsepos <= targetHorsepos;
      lostwon <= targetLostwon;
    end
  end


endmodule: game
