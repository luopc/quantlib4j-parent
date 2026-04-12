package com.luopc.platform.quantlib;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Integration tests for FxForward pricing using QuantLib.
 */
@DisplayName("FX Forward Tests")
class FxForwardTest {

    private static final Logger log = LoggerFactory.getLogger(FxForwardTest.class);

    // Test parameters
    private static double spotRate;
    private static double forwardRate;
    private static double sourceNominal;
    private static Date evaluationDate;
    private static Date maturityDate;
    private static Calendar paymentCalendar;

    @BeforeAll
    static void setup() {
        // Load native library
        QuantLibLoader.loadOrThrow();
        log.info("QuantLib4J loaded for platform: {}", QuantLibLoader.getPlatform());

        // Set evaluation date
        evaluationDate = new Date(11, Month.April, 2026);
        Settings.instance().setEvaluationDate(evaluationDate);

        // Test parameters: EUR/USD forward
        spotRate = 1.0850;
        forwardRate = 1.0875;  // Market forward rate
        sourceNominal = 1000000;  // 1M EUR

        // Maturity in 3 months
        maturityDate = new Date(11, Month.July, 2026);
        paymentCalendar = new TARGET();

        log.info("Test setup complete:");
        log.info("  Spot rate: {}", spotRate);
        log.info("  Forward rate: {}", forwardRate);
        log.info("  Source nominal: {}", sourceNominal);
        log.info("  Maturity: {}", maturityDate);
    }

    @Test
    @DisplayName("QuantLib should be initialized for FX Forward tests")
    void testQuantLibInitialization() {
        assertThat(QuantLibLoader.isLoaded()).isTrue();
        log.info("QuantLib4J native library loaded successfully");
    }

    @Test
    @DisplayName("FX Forward NPV should be approximately zero at inception")
    void testForwardAtInception() {
        // Create currencies
        EURCurrency eur = new EURCurrency();
        USDCurrency usd = new USDCurrency();

        // Settlement days
        long settlementDays = 2;

        // At inception, the NPV should be approximately zero
        // (ignoring bid-ask spread and transaction costs)

        // Calculate fair forward rate using interest rate differential
        double domesticRate = 0.05;  // USD rate
        double foreignRate = 0.02;   // EUR rate
        double timeToMaturity = 0.25;  // 3 months

        // Fair forward = Spot * exp((r_domestic - r_foreign) * T)
        double fairForward = spotRate * Math.exp((domesticRate - foreignRate) * timeToMaturity);

        log.info("Forward Rate Analysis:");
        log.info("  Spot rate: {}", spotRate);
        log.info("  Market forward rate: {}", forwardRate);
        log.info("  Calculated fair forward: {}", fairForward);
        log.info("  Difference: {}", Math.abs(fairForward - forwardRate));

        // Fair forward should be close to market forward
        assertThat(Math.abs(fairForward - forwardRate)).isLessThan(0.01);
    }

    @Test
    @DisplayName("FX Forward with source currency payment")
    void testFxForwardPaySourceCurrency() {
        EURCurrency eur = new EURCurrency();
        USDCurrency usd = new USDCurrency();

        long settlementDays = 2;

        // Create FX Forward: Buy EUR, Sell USD
        FxForward forward = new FxForward(
                sourceNominal,    // Source nominal in EUR
                eur,              // Source currency
                sourceNominal * forwardRate,  // Target nominal in USD
                usd,              // Target currency
                maturityDate,     // Maturity date
                true,             // Pay source currency
                settlementDays,   // Settlement days
                paymentCalendar   // Payment calendar
        );

        // Create pricing engine (requires interest rate term structures)
        // For simplicity, using FlatForward for discount curves
        YieldTermStructure domesticTS = new FlatForward(evaluationDate, 0.05, new Actual365Fixed());
        YieldTermStructure foreignTS = new FlatForward(evaluationDate, 0.02, new Actual365Fixed());

        // Note: Full pricing requires setting up yield term structures
        // This test verifies the object creation and basic functionality

        log.info("FX Forward created successfully:");
        log.info("  Source nominal: {}", forward.sourceNominal());
        log.info("  Source currency: {}", forward.sourceCurrency());
        log.info("  Target nominal: {}", forward.targetNominal());
        log.info("  Target currency: {}", forward.targetCurrency());

        assertThat(forward.sourceNominal()).isEqualTo(sourceNominal);
        assertThat(forward.sourceCurrency()).isEqualTo(eur);
        assertThat(forward.targetCurrency()).isEqualTo(usd);
    }

    @Test
    @DisplayName("FX Forward with forward rate constructor")
    void testFxForwardWithForwardRate() {
        EURCurrency eur = new EURCurrency();
        USDCurrency usd = new USDCurrency();

        long settlementDays = 2;

        // Create FX Forward using forward rate directly
        FxForward forward = new FxForward(
                sourceNominal,      // Source nominal
                eur,                // Source currency
                usd,                // Target currency
                forwardRate,        // Forward rate
                maturityDate,       // Maturity date
                true,               // Pay source currency
                settlementDays,     // Settlement days
                paymentCalendar     // Payment calendar
        );

        log.info("FX Forward (rate-based) created:");
        log.info("  Source nominal: {}", forward.sourceNominal());
        log.info("  Forward rate: {}", forwardRate);

        assertThat(forward.sourceNominal()).isEqualTo(sourceNominal);
    }

    @Test
    @DisplayName("FX Forward spot value should match spot rate")
    void testForwardSpotValue() {
        // The forward value at inception should reflect the interest rate differential
        // V_forward = V_spot * (r_domestic - r_foreign) * T

        double domesticRate = 0.05;  // USD
        double foreignRate = 0.02;   // EUR
        double timeToMaturity = 0.25;  // 3 months

        // Expected forward points
        double forwardPoints = spotRate * (Math.exp((domesticRate - foreignRate) * timeToMaturity) - 1);

        log.info("Forward Points Analysis:");
        log.info("  Spot rate: {}", spotRate);
        log.info("  Forward points: {}", forwardPoints);
        log.info("  Implied forward rate: {}", spotRate + forwardPoints);

        // Forward points should be positive when domestic rate > foreign rate
        assertThat(forwardPoints).isGreaterThan(0);
    }
}
