package simpaths.model;

import microsim.engine.SimulationEngine;
import microsim.statistics.regression.BinomialRegression;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.MockedStatic;
import org.mockito.Mockito;
import simpaths.data.Parameters;
import simpaths.model.enums.Les_c4;
import simpaths.model.enums.TargetShares;

import java.lang.reflect.Field;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * The retirement target (alignment_targets_retirement.xlsx) is the share of retired persons among those aged
 * {@link Parameters#MIN_AGE_TO_RETIRE} or older. These tests check that {@link RetirementAlignment} measures the
 * simulated share on the same population.
 */
class RetirementAlignmentTest {

    private static final int YEAR = 2020;
    private static final double TARGET_SHARE = 0.5;
    private static final double PROBABILITY_TO_RETIRE = 0.2;

    private MockedStatic<Parameters> parametersMock;
    private MockedStatic<SimulationEngine> engineMock;
    private int savedMinAgeToRetire;
    private boolean savedIntertemporalOptimisations;
    private Object savedRegR1a;
    private Object savedRegR1b;

    @BeforeEach
    void setUp() throws Exception {
        savedMinAgeToRetire = Parameters.MIN_AGE_TO_RETIRE;
        savedIntertemporalOptimisations = Parameters.enableIntertemporalOptimisations;
        Parameters.MIN_AGE_TO_RETIRE = 50;
        Parameters.enableIntertemporalOptimisations = false;

        SimPathsModel model = mock(SimPathsModel.class);
        when(model.getYear()).thenReturn(YEAR);
        SimulationEngine engine = mock(SimulationEngine.class);
        when(engine.getManager(SimPathsModel.class.getCanonicalName())).thenReturn(model);
        engineMock = Mockito.mockStatic(SimulationEngine.class);
        engineMock.when(SimulationEngine::getInstance).thenReturn(engine);

        // evaluate() scores persons on a parallel stream, and a static mock applies only to the thread that created
        // it, so the regressions are set in the fields their (real) getters read
        BinomialRegression regression = mock(BinomialRegression.class);
        when(regression.getScore(any(), eq(Person.DoublesVariables.class))).thenReturn(0.0);
        when(regression.getProbability(anyDouble())).thenReturn(PROBABILITY_TO_RETIRE);
        savedRegR1a = setParametersField("regRetirementR1a", regression);
        savedRegR1b = setParametersField("regRetirementR1b", regression);

        parametersMock = Mockito.mockStatic(Parameters.class, Mockito.CALLS_REAL_METHODS);
        parametersMock.when(() -> Parameters.getTargetShare(YEAR, TargetShares.Retirement)).thenReturn(TARGET_SHARE);
    }

    @AfterEach
    void tearDown() throws Exception {
        parametersMock.close();
        engineMock.close();
        setParametersField("regRetirementR1a", savedRegR1a);
        setParametersField("regRetirementR1b", savedRegR1b);
        Parameters.MIN_AGE_TO_RETIRE = savedMinAgeToRetire;
        Parameters.enableIntertemporalOptimisations = savedIntertemporalOptimisations;
    }

    private static Object setParametersField(String name, Object value) throws Exception {
        Field field = Parameters.class.getDeclaredField(name);
        field.setAccessible(true);
        Object previous = field.get(null);
        field.set(null, value);
        return previous;
    }

    private static Person person(int age, Les_c4 status, Les_c4 statusLag1) {
        Person person = mock(Person.class);
        when(person.getDag()).thenReturn(age);
        when(person.getLes_c4()).thenReturn(status);
        when(person.getLes_c4_lag1()).thenReturn(statusLag1);
        return person;
    }

    @Test
    void targetPopulationIsPersonsAgedMinAgeToRetireOrOlderWithALabourStatus() {
        assertFalse(RetirementAlignment.inTargetPopulation(person(49, Les_c4.EmployedOrSelfEmployed, Les_c4.EmployedOrSelfEmployed)));
        assertTrue(RetirementAlignment.inTargetPopulation(person(50, Les_c4.EmployedOrSelfEmployed, Les_c4.EmployedOrSelfEmployed)));
        assertTrue(RetirementAlignment.inTargetPopulation(person(90, Les_c4.Retired, Les_c4.Retired)));
        assertFalse(RetirementAlignment.inTargetPopulation(person(60, null, null)));

        // the age limit follows MIN_AGE_TO_RETIRE as set from parameters.xlsx
        Parameters.MIN_AGE_TO_RETIRE = 55;
        assertFalse(RetirementAlignment.inTargetPopulation(person(54, Les_c4.Retired, Les_c4.Retired)));
        assertTrue(RetirementAlignment.inTargetPopulation(person(55, Les_c4.NotEmployed, Les_c4.NotEmployed)));
    }

    @Test
    void retiredShareLeavesOutPersonsBelowMinAgeToRetire() {
        Set<Person> persons = new LinkedHashSet<>(List.of(
                person(30, Les_c4.EmployedOrSelfEmployed, Les_c4.EmployedOrSelfEmployed),  // below 50: not in the share
                person(45, Les_c4.NotEmployed, Les_c4.NotEmployed),                          // below 50: not in the share
                person(55, Les_c4.Retired, Les_c4.Retired),
                person(72, Les_c4.Retired, Les_c4.Retired),
                person(50, Les_c4.NotEmployed, Les_c4.NotEmployed),                          // retires with PROBABILITY_TO_RETIRE
                person(60, Les_c4.EmployedOrSelfEmployed, Les_c4.EmployedOrSelfEmployed)));  // retires with PROBABILITY_TO_RETIRE

        RetirementAlignment alignment = new RetirementAlignment(persons);

        // expected retired share among the four persons aged 50+: (2 + 2 * 0.2) / 4 = 0.6, not 2.4 / 6 over everyone
        double expectedRetiredShare = (2 + 2 * PROBABILITY_TO_RETIRE) / 4;
        assertEquals(TARGET_SHARE - expectedRetiredShare, alignment.evaluate(new double[]{0.0}), 1e-12);
    }
}
