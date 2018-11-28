#
# Primary Recovery Area
b .
#
# After-Image Area
a .
a .
a .
#
# Schema Area (System Tables)
# Use 32 for 1/2/4K DB Block Sizes
#d "Schema Area":6,32;1 .
# Use 64 for 8K DB Block Sizes
d "Schema Area":6,64;1 .
#
# Default Data Area for Application
d "Data Area":10,256;8 .
#
# Default Index Area for Application
d "Index Area":20,32;8 .
#
# Default LOB Area for Application
d "LOB Area":30,32;8 .
#
# Area for Audit Data
d "Audit Data Area":40,256;8 .
#
# Area for Audit Indexes
d "Audit Index Area":50,32;8 .
#
# Data Area for Change Tracking
d "Change Data Area":60,256;8 .
#
# Index Area for Change Tracking
d "Change Index Area":70,32;8 .
#
# Transparent Data Encryption Policy Area
e "Encryption Policy Area":80,32;8 .
#
# Transaction Log for 2-Phase Commit
t . f 1280
