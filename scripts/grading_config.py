# grading_config.py : calibration and grading rules used by grade_asparagus.py.
# EVERY NUMBER HERE IS A PLACEHOLDER. Calibrate MM_PER_PX with a ruler in the picture and
# GRAMS_PER_CM3 with a kitchen scale, and set the classes to your buyer's specification.
MM_PER_PX     = 0.9      # millimetres per pixel (square pixels assumed)
GRAMS_PER_CM3 = 1.0      # effective density of a spear

MIN_LENGTH_MM = 150      # shorter spears are rejected
MAX_BOW_MM    = 8        # largest allowed distance of the centre line from a straight line
# (name, upper diameter limit in mm), checked in order, using the MEDIAN diameter of the spear
DIAMETER_CLASSES = [("thin", 10), ("medium", 16), ("large", 22), ("jumbo", 1e9)]
