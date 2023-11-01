version 1.0

struct FastqPair {
    File fastq_1
    File fastq_2
    String read_group
}

# Concatenate the fq pairs and read group to a command line
# that can be directly fed into the pbrun command 
task parse_inputs {
    input {
        FastqPair fq_pair
    }

    command {
        echo "--in-fq ~{fq_pair.fastq_1} ~{fq_pair.fastq_2} ~{fq_pair.read_group}"
    }

    output {
        String command_line = read_lines(stdout())
    }
}