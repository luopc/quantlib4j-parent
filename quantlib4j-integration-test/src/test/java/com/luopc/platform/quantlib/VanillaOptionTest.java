package com.luopc.platform.quantlib;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Integration tests for VanillaOption pricing using QuantLib.
 *
 * <p>Tests Black-Scholes pricing against known analytical results.</p>
 */
@DisplayName("Vanilla Option Tests")
class VanillaOptionTest {

    private static final Logger log = LoggerFactory.getLogger(VanillaOptionTest.class);

    // Test parameters
    private static double spot;
    private static double strike;
    private static double riskFreeRate;
    private static double dividendYield;
    private static double volatility;
    private static Date evaluationDate;
    private static Date maturityDate;

    @BeforeAll
    static void setup() {
        // Load native library
        QuantLibLoader.loadOrThrow();
        log.info("QuantLib4J loaded for platform: {}", QuantLibLoader.getPlatform());

        // Set evaluation date to 2026-04-11
        evaluationDate = new Date(11, Month.April, 2026);
        Settings.instance().setEvaluationDate(evaluationDate);

        // Test parameters: EUR/USD call option
        spot = 1.0850;           // Spot rate
        strike = 1.0900;         // Strike rate
        riskFreeRate = 0.05;     // 5% USD risk-free rate
        dividendYield = 0.02;    // 2% EUR dividend yield
        volatility = 0.10;       // 10% volatility

        // Maturity in 3 months
        maturityDate = new Date(11, Month.July, 2026);

        log.info("Test setup complete:");
        log.info("  Spot: {}", spot);
        log.info("  Strike: {}", strike);
        log.info("  Risk-free rate: {}%", riskFreeRate * 100);
        log.info("  Dividend yield: {}%", dividendYield * 100);
        log.info("  Volatility: {}%", volatility * 100);
    }

    @Test
    @DisplayName("QuantLib should be initialized successfully")
    void testQuantLibInitialization() {
        assertThat(QuantLibLoader.isLoaded()).isTrue();
        log.info("QuantLib4J native library loaded successfully");
    }

    @Test
    @DisplayName("EUR Call option should price correctly using Black-Scholes")
    void testEurCallOptionPricing() {
        // Create the Black-Scholes process
        BlackScholesProcess process = createBlackScholesProcess();

        // Create exercise
        EuropeanExercise exercise = new EuropeanExercise(maturityDate);

        // Create payoff
        PlainVanillaPayoff payoff = new PlainVanillaPayoff(Option.Type.Call, strike);

        // Create option
        VanillaOption option = new VanillaOption(payoff, exercise);

        // Set pricing engine
        AnalyticEuropeanEngine engine = new AnalyticEuropeanEngine(process);
        option.setPricingEngine(engine);

        // Calculate NPV
        double npv = option.NPV();

        // Log results
        log.info("Call Option NPV: {}", npv);
        log.info("Call Option Delta: {}", option.delta());
        log.info("Call Option Gamma: {}", option.gamma());
        log.info("Call Option Vega: {}", option.vega());
        log.info("Call Option Theta: {}", option.theta());
        log.info("Call Option Rho: {}", option.rho());

        // Assertions
        assertThat(npv).isGreaterThan(0.0);
        assertThat(npv).isLessThan(spot);  // Price should be less than spot

        // Delta should be positive for call
        double delta = option.delta();
        assertThat(delta).isGreaterThan(0.0);
        assertThat(delta).isLessThan(1.0);
    }

    @Test
    @DisplayName("EUR Put option should price correctly")
    void testEurPutOptionPricing() {
        // Create the Black-Scholes process
        BlackScholesProcess process = createBlackScholesProcess();

        // Create exercise
        EuropeanExercise exercise = new EuropeanExercise(maturityDate);

        // Create payoff (put)
        PlainVanillaPayoff payoff = new PlainVanillaPayoff(Option.Type.Put, strike);

        // Create option
        VanillaOption option = new VanillaOption(payoff, exercise);

        // Set pricing engine
        AnalyticEuropeanEngine engine = new AnalyticEuropeanEngine(process);
        option.setPricingEngine(engine);

        // Calculate NPV
        double npv = option.NPV();

        // Log results
        log.info("Put Option NPV: {}", npv);
        log.info("Put Option Delta: {}", option.delta());

        // Assertions
        assertThat(npv).isGreaterThan(0.0);

        // Delta should be negative for put
        double delta = option.delta();
        assertThat(delta).isLessThan(0.0);
        assertThat(delta).isGreaterThan(-1.0);
    }

    @Test
    @DisplayName("Put-Call parity should hold")
    void testPutCallParity() {
        // Create the Black-Scholes process
        BlackScholesProcess process = createBlackScholesProcess();

        // Time to maturity in years
        double T = 0.25;  // 3 months

        // Call option
        EuropeanExercise exercise = new EuropeanExercise(maturityDate);
        PlainVanillaPayoff callPayoff = new PlainVanillaPayoff(Option.Type.Call, strike);
        VanillaOption callOption = new VanillaOption(callPayoff, exercise);
        callOption.setPricingEngine(new AnalyticEuropeanEngine(process));
        double callPrice = callOption.NPV();

        // Put option
        PlainVanillaPayoff putPayoff = new PlainVanillaPayoff(Option.Type.Put, strike);
        VanillaOption putOption = new VanillaOption(putPayoff, exercise);
        putOption.setPricingEngine(new AnalyticEuropeanEngine(process));
        double putPrice = putOption.NPV();

        // Calculate put-call parity: C - P = S*e^(-q*T) - K*e^(-r*T)
        double callPutDiff = callPrice - putPrice;
        double parityCheck = spot * Math.exp(-dividendYield * T) - strike * Math.exp(-riskFreeRate * T);

        log.info("Put-Call Parity Test:");
        log.info("  Call Price: {}", callPrice);
        log.info("  Put Price: {}", putPrice);
        log.info("  C - P: {}", callPutDiff);
        log.info("  S*e^(-qT) - K*e^(-rT): {}", parityCheck);
        log.info("  Difference: {}", Math.abs(callPutDiff - parityCheck));

        // Put-call parity should hold (within numerical tolerance)
        assertThat(Math.abs(callPutDiff - parityCheck)).isLessThan(0.001);
    }

    @Test
    @DisplayName("Implied volatility calculation should work")
    void testImpliedVolatility() {
        // Create the Black-Scholes process
        BlackScholesProcess process = createBlackScholesProcess();

        // Create option
        EuropeanExercise exercise = new EuropeanExercise(maturityDate);
        PlainVanillaPayoff payoff = new PlainVanillaPayoff(Option.Type.Call, strike);
        VanillaOption option = new VanillaOption(payoff, exercise);
        option.setPricingEngine(new AnalyticEuropeanEngine(process));

        // Calculate market price with known volatility
        double marketPrice = option.NPV();
        log.info("Market price (ATM): {}", marketPrice);

        // Calculate implied volatility
        double impliedVol = option.impliedVolatility(marketPrice, process, 1e-6, 100);

        log.info("Implied volatility: {}%", impliedVol * 100);

        // Implied vol should be close to the actual vol
        assertThat(Math.abs(impliedVol - volatility)).isLessThan(0.001);
    }

    /**
     * Helper method to create Black-Scholes process.
     */
    private BlackScholesProcess createBlackScholesProcess() {
        // Create quote handle for spot
        SimpleQuote spotQuote = new SimpleQuote(spot);
        QuoteHandle spotHandle = new QuoteHandle(spotQuote);

        // Create flat risk-free term structure
        YieldTermStructure rTS = new FlatForward(evaluationDate, riskFreeRate, new Actual365Fixed());
        YieldTermStructureHandle rHandle = new YieldTermStructureHandle(rTS);

        // Create flat dividend term structure
        YieldTermStructure qTS = new FlatForward(evaluationDate, dividendYield, new Actual365Fixed());
        YieldTermStructureHandle qHandle = new YieldTermStructureHandle(qTS);

        // Create flat volatility structure using BlackConstantVol
        BlackConstantVol vol = new BlackConstantVol(
                evaluationDate,
                new TARGET(),
                volatility,
                new Actual365Fixed()
        );
        BlackVolTermStructureHandle volHandle = new BlackVolTermStructureHandle(vol);

        // Create Black-Scholes process
        return new BlackScholesProcess(spotHandle, rHandle, volHandle);
    }
}
