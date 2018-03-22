// See LICENSE for license details.

`ifndef RESET_DELAY
 `define RESET_DELAY 777.7
 `define ADC_RESET_DELAY 376.4
`endif

`ifndef PI
  `define PI 3.1415926535897932
`endif

module TestDriver;

  reg core_clock = 1'b0;
  reg dsp_clock = 1'b0;
  reg serial_clock = 1'b0;
  reg reset = 1'b1;
  reg adc_reset = 1'b1;

  import "DPI" function real sin(real x);     //using sin function in C
  real adcinp = 0.2; 
  real adcinm = 0.2;

  // [stevo]: make sine wave
  `define ADCPERIOD 5
  always #(`ADCPERIOD/100) begin
      //adcinp = 0.2 + 0.15*sin(2*`PI/`ADCPERIOD*$realtime()) + real'($random)/36'hfffffffff;
      //adcinm = 0.2 + 0.15*sin(2*`PI/`ADCPERIOD*$realtime()+`PI) + real'($random)/36'hfffffffff;
      adcinp = 0.2 + 0.15*sin(2*`PI/`ADCPERIOD*$realtime());
      adcinm = 0.2 + 0.15*sin(2*`PI/`ADCPERIOD*$realtime()+`PI);
  end  

  // digital clocks
  always #(`SERIAL_CLOCK_PERIOD/2.0) serial_clock = ~serial_clock;
  always #(`CORE_CLOCK_PERIOD/2.0) core_clock = ~core_clock;
  always #(`DSP_CLOCK_PERIOD/2.0) dsp_clock = ~dsp_clock;
  initial #(`RESET_DELAY) reset = 0;
  initial #(`ADC_RESET_DELAY) adc_reset = 0;

  // Read input arguments and initialize
  reg verbose = 1'b0;
  reg _ret = 1'b0;
  wire printf_cond = verbose && !reset;
  reg [63:0] max_cycles = 0;
  reg [63:0] trace_count = 0;
  reg [1023:0] vcdplusfile = 0;
  reg [1023:0] vcdfile = 0;
  int unsigned rand_value;
  initial
  begin
    _ret = $value$plusargs("max-cycles=%d", max_cycles);
    verbose = $test$plusargs("verbose");

    // do not delete the lines below.
    // $random function needs to be called with the seed once to affect all
    // the downstream $random functions within the Chisel-generated Verilog
    // code.
    // $urandom is seeded via cmdline (+ntb_random_seed in VCS) but that
    // doesn't seed $random.
    rand_value = $random;
`ifdef VCS
      rand_value = $urandom;
      rand_value = $random(rand_value);
    if (verbose) begin
      $fdisplay(stderr, "testing $random %0x seed %d", rand_value, unsigned'($get_initial_random_seed));
    end
`else
    if (verbose) begin
      $fdisplay(stderr, "testing $random %0x", rand_value);
    end
`endif

`ifdef DEBUG

    if ($value$plusargs("vcdplusfile=%s", vcdplusfile))
    begin
`ifdef VCS
      $vcdplusfile(vcdplusfile);
      $vcdpluson(0);
      $vcdplusmemon(0);
`else
      $fdisplay(stderr, "Error: +vcdplusfile is VCS-only; use +vcdfile instead");
      $fatal;
`endif
    end

    if ($value$plusargs("vcdfile=%s", vcdfile))
    begin
      $dumpfile(vcdfile);
      $dumpvars(0, testHarness);
      $dumpon;
    end
`ifdef VCS
`define VCDPLUSCLOSE $vcdplusclose; $dumpoff;
`else
`define VCDPLUSCLOSE $dumpoff;
`endif
`else
  // No +define+DEBUG
`define VCDPLUSCLOSE

    if ($test$plusargs("vcdplusfile=") || $test$plusargs("vcdfile="))
    begin
      $fdisplay(stderr, "Error: +vcdfile or +vcdplusfile requested but compile did not have +define+DEBUG enabled");
      $fatal;
    end

`endif
  end

`ifdef TESTBENCH_IN_UVM
  // UVM library has its own way to manage end-of-simulation.
  // A UVM-based testbench will raise an objection, watch this signal until this goes 1, then drop the objection.
  reg finish_request = 1'b0;
`endif
  reg [255:0] reason = "";
  reg failure = 1'b0;
  wire success;
  integer stderr = 32'h80000002;
  always @(posedge core_clock)
  begin
`ifdef GATE_LEVEL
    if (verbose)
    begin
      $fdisplay(stderr, "C: %10d", trace_count);
    end
`endif

    trace_count = trace_count + 1;
    if (!reset)
    begin
      if (max_cycles > 0 && trace_count > max_cycles)
      begin
        reason = " (timeout)";
        failure = 1'b1;
      end

      if (failure)
      begin
        $fdisplay(stderr, "*** FAILED ***%s after %d simulation cycles", reason, trace_count);
        `VCDPLUSCLOSE
        $fatal;
      end

      if (success)
      begin
        if (verbose)
          $fdisplay(stderr, "Completed after %d simulation cycles", trace_count);
        `VCDPLUSCLOSE
`ifdef TESTBENCH_IN_UVM
        finish_request = 1;
`else
        $finish;
`endif
      end
    end
  end

  wire [1:0] dummy;
  TestHarness testHarness(
    // TSI clock and reset
    .clock(serial_clock),
    .reset(reset),
    // core clock and reset
    .io_CLKRXVIP(core_clock),
    .io_CLKRXVIN(~core_clock),
    .io_core_reset(reset),
    // ADC signals and DSP clock and reset
    .io_adcclkreset(adc_reset),
    .io_dsp_reset(reset),
    .io_ADCBIAS(),
    .io_ADCINP(adcinp),
    .io_ADCINM(adcinm),
    .io_ADCCLKP(dsp_clock),
    .io_ADCCLKM(~dsp_clock),
    // test IO
    .io_success(success)
  );

endmodule
