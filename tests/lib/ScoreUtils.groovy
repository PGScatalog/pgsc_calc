class ScoreUtils {
    static void assertScoresMatch(ArrayList actual, ArrayList expected) {
        assert actual.size() == expected.size()
        def reference = roundList(expected)
        roundList(actual).eachWithIndex { row, i -> assert row == reference[i] }
    }

    static def roundList(ArrayList l, int decimals = 6) {
        l.collect { row ->
            row.collect { item ->
                try {
                    // try to parse as a number
                    def num = new BigDecimal(item)
                    num.setScale(decimals, BigDecimal.ROUND_HALF_UP)
                } catch (NumberFormatException e) {
                    // not a number, return original string
                    item
                }
            }
        }
    }
}