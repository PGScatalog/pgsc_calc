.mode tabs
.import scorefile.txt scorefile
.import target.txt target

CREATE INDEX idx_scorefile on scorefile (chrom, pos);
CREATE INDEX idx_target ON target ('#CHROM', pos);

-- match scorefile against target
-- matched variants: EA = REF and OA = ALT
CREATE TABLE matched AS
SELECT
    scorefile.chrom,
    scorefile.pos,
    scorefile.effect,
    scorefile.other,
    scorefile.weight
FROM
    scorefile
INNER JOIN target ON scorefile.chrom = target.'#CHROM' AND
    scorefile.pos = target.pos AND
    scorefile.effect = target.'REF' AND
    scorefile.other = target.ALT;

-- matched variants: EA = ALT and OA = REF
INSERT INTO matched
SELECT
    scorefile.chrom,
    scorefile.pos,
    scorefile.effect,
    scorefile.other,
    scorefile.weight
FROM
    scorefile
INNER JOIN target ON scorefile.chrom = target.'#CHROM' AND
    scorefile.pos = target.pos AND
    scorefile.effect = target.ALT AND
    scorefile.other = target.'REF';

-- get unmatched variants
CREATE TABLE unmatched AS
SELECT
    scorefile.chrom,
    scorefile.pos,
    scorefile.effect,
    scorefile.other,
    scorefile.weight
FROM
    scorefile
INNER JOIN
-- subquery: exclude matched variant positions
    (SELECT scorefile.chrom, scorefile.pos FROM scorefile
        EXCEPT
    SELECT matched.chrom, matched.pos FROM matched)
USING (chrom, pos);

-- flip nucleotides in unmatched
CREATE TABLE flip (
    nucleotide TEXT NOT NULL,
    complement TEXT NOT NULL
);

INSERT INTO flip (nucleotide, complement)
VALUES
    ('A', 'T'),
    ('T', 'A'),
    ('C', 'G'),
    ('G', 'C');

CREATE TABLE flipped AS
SELECT
    chrom,
    pos,
    effect,
    other,
    weight
FROM
    -- subquery: get a table with flipped effect alleles
    (SELECT chrom, pos, complement AS effect, weight FROM unmatched
    INNER JOIN flip
    ON unmatched.effect = flip.nucleotide)
INNER JOIN
    -- subquery: get a table with flipped other alleles too
    (SELECT chrom, pos, complement AS other from unmatched
    INNER JOIN flip
    ON unmatched.other = flip.nucleotide)
USING (chrom, pos);

-- match flipped in target

INSERT INTO matched
 -- match by EA = REF and OA = ALT
SELECT
    flipped.chrom,
    flipped.pos,
    flipped.effect,
    flipped.other,
    flipped.weight
FROM
    flipped
INNER JOIN
    target
ON
    flipped.chrom = target.'#CHROM' AND
    flipped.pos = target.pos AND
    flipped.effect = target.'REF' AND
    flipped.other = target.ALT
UNION ALL
-- match by EA = ALT and OA = REF
SELECT
    flipped.chrom,
    flipped.pos,
    flipped.effect,
    flipped.other,
    flipped.weight
FROM
    flipped
INNER JOIN
    target
ON
    flipped.chrom = target.'#CHROM' AND
    flipped.pos = target.pos AND
    flipped.effect = target.ALT AND
    flipped.other = target.'REF';

-- write out matched table to scorefile format

.once matched.scorefile.tmp

SELECT
    chrom || ':' || pos || ':' || effect || ':' || other AS id,
    effect,
    weight
FROM
    (SELECT
        chrom,
        pos,
        effect,
        other,
        weight
    FROM matched
    ORDER BY chrom, pos);
