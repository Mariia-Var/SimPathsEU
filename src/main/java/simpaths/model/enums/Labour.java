package simpaths.model.enums;

import microsim.statistics.regression.IntegerValuedEnum;
import simpaths.data.Parameters;
import simpaths.model.Person;

import java.util.Objects;

import static simpaths.data.Parameters.COUNTRY_STRING;

public enum Labour implements IntegerValuedEnum {
    //int categoryId, int femaleMin, int femaleMax, int maleMin, int maleMax, int femaleRep, int maleRep
    // femaleRep / maleRep: representative hours of the bracket, i.e. the hours the labour-supply utility is
    // evaluated at when choosing between brackets (they should match the hours used in the estimation)
    ZERO(0, 0, 0, 0, 0, 0, 0),  // 0 hours for both genders

    //HU
    // TODO: representative hours are placeholder bracket midpoints; confirm against the HU estimation
    CATEGORY_HU_1(11, 1, 39, 1, 39, 20, 20),
    CATEGORY_HU_2(12, 40, 40, 40, 40, 40, 40),
    CATEGORY_HU_3(13, 41, Parameters.MAX_LABOUR_HOURS_IN_WEEK, 41, Parameters.MAX_LABOUR_HOURS_IN_WEEK, 50, 50),

    //PL
    // TODO: representative hours are placeholder bracket midpoints; confirm against the PL estimation
    CATEGORY_PL_1(21, 1, 39, 1, 39, 20, 20),  //sub categoryId 20 to 1
    CATEGORY_PL_2(22, 40, 40, 40, 40, 40, 40),
    CATEGORY_PL_3(23, 41, Parameters.MAX_LABOUR_HOURS_IN_WEEK, 41, Parameters.MAX_LABOUR_HOURS_IN_WEEK, 50, 50),

    //IT
    // TODO: representative hours are placeholder bracket midpoints; confirm against the IT estimation
    CATEGORY_IT_1(31, 1, 29,   1, 35, 15, 18),   // [1-29] vs [1-35]
    CATEGORY_IT_2(32, 30, 35,  36, 39, 32, 37),  // [30-35] vs [36-39]
    CATEGORY_IT_3(33, 36, 39,  40, 49, 37, 44),  // [36-39] vs [40-49]
    CATEGORY_IT_4(34, 40, 55, 50, 65, 47, 57), // [40+] vs [50+]

    //EL
    // TODO: representative hours are placeholder bracket midpoints; confirm against the EL estimation
    CATEGORY_EL_1(41, 1, 39,   1, 39, 20, 20),   // [1-39]
    CATEGORY_EL_2(42, 40, 40,  40, 40, 40, 40),  // [40]
    CATEGORY_EL_3(43, 41, Parameters.MAX_LABOUR_HOURS_IN_WEEK,  41, Parameters.MAX_LABOUR_HOURS_IN_WEEK, 50, 50),  // [41+]

    //ES
    // ES_1 and ES_3 realise at their representative hours; only ES_2 spreads realised hours across its bracket
    CATEGORY_ES_1(51, 6, 35, 6, 35, 30, 30, false),
    CATEGORY_ES_2(52, 36, 40, 36, 40, 40, 40),
    CATEGORY_ES_3(53, 41, Parameters.MAX_LABOUR_HOURS_IN_WEEK, 41, Parameters.MAX_LABOUR_HOURS_IN_WEEK, 50, 50, false);




    private final int categoryId;
    private final int femaleMin, femaleMax;
    private final int maleMin, maleMax;
    private final int femaleRep, maleRep;
    private final boolean spreadRealisedHours;  // true: realised hours spread within [min, max]; false: realised at the representative hours

    Labour(int categoryId, int femaleMin, int femaleMax, int maleMin, int maleMax, int femaleRep, int maleRep) {
        this(categoryId, femaleMin, femaleMax, maleMin, maleMax, femaleRep, maleRep, true);
    }

    Labour(int categoryId, int femaleMin, int femaleMax, int maleMin, int maleMax, int femaleRep, int maleRep,
           boolean spreadRealisedHours) {
        this.categoryId = categoryId;
        this.femaleMin = femaleMin;
        this.femaleMax = femaleMax;
        this.maleMin = maleMin;
        this.maleMax = maleMax;
        this.femaleRep = femaleRep;
        this.maleRep = maleRep;
        this.spreadRealisedHours = spreadRealisedHours;
    }

    @Override
    public int getValue() {
        return categoryId;  // Now returns category ID instead of hours
    }

    // Gender-aware conversion methods
    public static Labour convertHoursToLabour(double hoursWorked, Gender gender) {
        if (hoursWorked <= 0) return ZERO;

        return switch (gender) {
            case Female -> convertFemaleHours(hoursWorked);
            default -> convertMaleHours(hoursWorked);
        };
    }

    private static Labour convertFemaleHours(double hours) {

        String country = COUNTRY_STRING;
        if (Objects.equals(country, "EL")) {
            if (hours <= 39) return CATEGORY_EL_1;
            else if (hours <= 40) return CATEGORY_EL_2;
            else return CATEGORY_EL_3;
        }
        else if (Objects.equals(country, "IT")) {
            if (hours <= 29) return CATEGORY_IT_1;
            else if (hours <= 35) return CATEGORY_IT_2;
            else if (hours <= 39) return CATEGORY_IT_3;
            else return CATEGORY_IT_4;
        }
        else if (Objects.equals(country, "PL")) {
            if (hours <= 39) return CATEGORY_PL_1;
            else if (hours <= 40) return CATEGORY_PL_2;
            else return CATEGORY_PL_3;
        }
        else if (Objects.equals(country, "ES")) {
            if (hours < 6) return ZERO;          // 1-5 hours: outside the estimated choice set
            else if (hours <= 35) return CATEGORY_ES_1;
            else if (hours <= 40) return CATEGORY_ES_2;
            else return CATEGORY_ES_3;
        }
        else if (Objects.equals(country, "HU")) {
            if (hours <= 39) return CATEGORY_HU_1;
            else if (hours <= 40) return CATEGORY_HU_2;
            else return CATEGORY_HU_3;
        }
        else {
            throw new IllegalArgumentException("Country not recognized: " + COUNTRY_STRING);
        }
    }


    private static Labour convertMaleHours(double hours) {
        String country = COUNTRY_STRING;
        if (Objects.equals(country, "EL")) {
            if (hours <= 39) return CATEGORY_EL_1;
            else if (hours <= 40) return CATEGORY_EL_2;
            else return CATEGORY_EL_3;
        }
        else if (Objects.equals(country, "IT")) {
            if (hours <= 35) return CATEGORY_IT_1;
            else if (hours <= 39) return CATEGORY_IT_2;
            else if (hours <= 49) return CATEGORY_IT_3;
            else return CATEGORY_IT_4;
        }
        else if (Objects.equals(country, "PL")) {
            if (hours <= 39) return CATEGORY_PL_1;
            else if (hours <= 40) return CATEGORY_PL_2;
            else return CATEGORY_PL_3;
        }
        else if (Objects.equals(country, "ES")) {
            if (hours < 6) return ZERO;          // 1-5 hours: outside the estimated choice set
            else if (hours <= 35) return CATEGORY_ES_1;
            else if (hours <= 40) return CATEGORY_ES_2;
            else return CATEGORY_ES_3;
        }
        else if (Objects.equals(country, "HU")) {
            if (hours <= 39) return CATEGORY_HU_1;
            else if (hours <= 40) return CATEGORY_HU_2;
            else return CATEGORY_HU_3;
        }
        else {
            throw new IllegalArgumentException("Country not recognized: " + COUNTRY_STRING);
        }
    }

    public static Labour[] valuesForCurrentCountry() {
        return valuesForCountry(COUNTRY_STRING);
    }

    public static Labour[] valuesForCountry(String country) {
        if (country == null || country.isEmpty()) {
            return values();
        }
        return switch (country) {
            case "EL" -> new Labour[]{ZERO, CATEGORY_EL_1, CATEGORY_EL_2, CATEGORY_EL_3};
            case "IT" -> new Labour[]{ZERO, CATEGORY_IT_1, CATEGORY_IT_2, CATEGORY_IT_3, CATEGORY_IT_4};
            case "PL" -> new Labour[]{ZERO, CATEGORY_PL_1, CATEGORY_PL_2, CATEGORY_PL_3};
            case "ES" -> new Labour[]{ZERO, CATEGORY_ES_1, CATEGORY_ES_2, CATEGORY_ES_3};
            case "HU" -> new Labour[]{ZERO, CATEGORY_HU_1, CATEGORY_HU_2, CATEGORY_HU_3};
            default -> values();
        };
    }

    public int getRepresentativeHours(Gender gender) {
        return (gender == Gender.Female) ? femaleRep : maleRep;
    }

    public int getHours(Person person) {
        if (this == ZERO) return 0;
        if (person == null)
            throw new IllegalArgumentException("hours for " + name() + " are gender specific, so they cannot be evaluated without a person");

        Gender gender = person.getDgn();
        if (Parameters.useRepresentativeHours && person.isEvaluatingLabourChoice())
            return getRepresentativeHours(gender);

        int min = (gender == Gender.Female) ? femaleMin : maleMin;
        int max = (gender == Gender.Female) ? femaleMax : maleMax;

        // brackets that do not spread hours use a single point: the representative hours while the choice is scored,
        // and for realised hours either those or (with USE_MIDPOINT_HOURS) the bracket midpoint
        if (!spreadRealisedHours)
            return (Parameters.USE_MIDPOINT_HOURS && !person.isEvaluatingLabourChoice()) ? (min + max) / 2 : getRepresentativeHours(gender);

        if (Parameters.USE_CONTINUOUS_LABOUR_SUPPLY_HOURS) {
            // each whole hour in [min, max] gets an equal share of the unit interval; min() guards a draw of exactly 1
            double draw = person.getLabourSupplyHoursDraw();
            return Math.min(min + (int) (draw * (max - min + 1)), max);
        } else {
            // Return midpoint for discrete mode
            return (min + max) / 2;
        }
    }
}
