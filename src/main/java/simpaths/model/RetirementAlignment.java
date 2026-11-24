package simpaths.model;

import microsim.engine.SimulationEngine;
import simpaths.data.IEvaluation;
import simpaths.data.Parameters;
import simpaths.model.decisions.DecisionParams;
import simpaths.model.enums.Labour;
import simpaths.model.enums.Les_c4;
import simpaths.model.enums.TargetShares;

import java.util.Set;


/**
 * RetirementAlignment adjusts the probability of retiring.
 * The object is designed to assist modification of the intercept of the "retirement" models.
 *
 * The target (alignment_targets_retirement.xlsx) is the share of retired persons among those aged
 * {@link Parameters#MIN_AGE_TO_RETIRE} or older with a labour status, the population of
 * {@link #inTargetPopulation(Person)}. Retirement is considered only from that age, so younger persons do not enter
 * the share.
 *
 * A search routine is used to find the value by which the intercept should be adjusted.
 * If the projected share of retired individuals in the target population differs from the desired target by more than a specified threshold,
 * then the intercept is adjusted and the share re-evaluated.
 *
 * Importantly, the adjustment needs to be only found once. Modified intercepts can then be used in subsequent simulations.
 */
public class RetirementAlignment implements IEvaluation {

    private double targetRetiredShare;
    private Set<Person> persons;
    private SimPathsModel model;
    private long numInTargetPopulation;
    private long numAlreadyRetired;
    private long numDeterministicRetire;
    private boolean intertemporalPath;


    // CONSTRUCTOR
    public RetirementAlignment(Set<Person> persons) {
        this.model = (SimPathsModel) SimulationEngine.getInstance().getManager(SimPathsModel.class.getCanonicalName());
        this.persons = persons;
        targetRetiredShare = Parameters.getTargetShare(model.getYear(), TargetShares.Retirement);
        intertemporalPath = Parameters.enableIntertemporalOptimisations && DecisionParams.flagRetirement;

        numInTargetPopulation = persons.stream()
                .filter(RetirementAlignment::inTargetPopulation)
                .count();
        numAlreadyRetired = persons.stream()
                .filter(person -> inTargetPopulation(person) && Les_c4.Retired.equals(person.getLes_c4()))
                .count();
        if (intertemporalPath) {
            numDeterministicRetire = persons.stream()
                    .filter(person -> inTargetPopulation(person)
                            && !Les_c4.Retired.equals(person.getLes_c4())
                            && !Les_c4.Retired.equals(person.getLes_c4_lag1())
                            && Labour.ZERO.equals(person.getLabourSupplyWeekly_L1()))
                    .count();
        } else {
            numDeterministicRetire = 0;
        }
    }


    /**
     * Whether a person belongs to the population of the retirement target: aged {@link Parameters#MIN_AGE_TO_RETIRE}
     * or older, with a labour status. The target is computed on the same population from the initial populations
     * (input_processing/alignment_targets/&lt;CC&gt;/01_retirement_targets_initpopdataEU.do), and
     * AlignmentStatistics reports the simulated share on it.
     */
    public static boolean inTargetPopulation(Person person) {
        return person.getLes_c4() != null && person.getDag() >= Parameters.MIN_AGE_TO_RETIRE;
    }


    /**
     * Evaluates the discrepancy between the expected (smooth) retired share at a candidate adjustment
     * and the target share. Uses sum of probit probabilities rather than stochastic realisations,
     * yielding a smooth, deterministic objective for the root search.
     *
     * @param args An array of parameters, where args[0] represents the probit intercept adjustment.
     * @return target retired share minus expected retired share of the target population at the given adjustment.
     */
    @Override
    public double evaluate(double[] args) {

        if (numInTargetPopulation == 0) return targetRetiredShare;

        double expectedRetiring;
        if (intertemporalPath) {
            expectedRetiring = numDeterministicRetire;
        } else {
            expectedRetiring = persons.parallelStream()
                    .filter(person -> inTargetPopulation(person)
                            && !Les_c4.Retired.equals(person.getLes_c4())
                            && !Les_c4.Retired.equals(person.getLes_c4_lag1()))
                    .mapToDouble(person -> {
                        double score;
                        if (person.getPartner() != null) {
                            score = Parameters.getRegRetirementR1b().getScore(person, Person.DoublesVariables.class);
                            return Parameters.getRegRetirementR1b().getProbability(score + args[0]);
                        } else {
                            score = Parameters.getRegRetirementR1a().getScore(person, Person.DoublesVariables.class);
                            return Parameters.getRegRetirementR1a().getProbability(score + args[0]);
                        }
                    })
                    .sum();
        }

        double expectedRetiredShare = (numAlreadyRetired + expectedRetiring) / numInTargetPopulation;
        return targetRetiredShare - expectedRetiredShare;
    }
}
