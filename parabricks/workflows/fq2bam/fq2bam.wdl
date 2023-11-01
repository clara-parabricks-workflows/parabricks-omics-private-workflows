version 1.0
# Copyright 2021 NVIDIA CORPORATION & AFFILIATES

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
        String docker = "public.ecr.aws/amazonlinux/amazonlinux:minimal"
    }

    command {
        set -e
        echo "--in-fq ~{fq_pair.fastq_1} ~{fq_pair.fastq_2} ~{fq_pair.read_group}"
    }

    output {
        String command_line = read_lines(stdout())[-1]
    }

    runtime {
        docker: docker
        cpu: 4
        memory: "8 GiB"
    }
}

task fq2bam {
    input {
        Array[FastqPair] fastq_pairs
        Array[String] fastq_command_line

        File? inputKnownSitesVCF
        File inputRefTarball

        String docker
    }

    String tmpDir = "tmp_fq2bam"
    String ref = basename(inputRefTarball, ".tar")
    String outbase = basename(basename(basename(basename(fastq_pairs[0].fastq_1, ".gz"), ".fastq"), ".fq"), "_1")

    command {
        set -e
        set -x
        set -o pipefail
        mkdir -p ~{tmpDir} && \
        time tar xf ~{inputRefTarball} && \
        time ~{pbPATH} fq2bam \
        --tmp-dir ~{tmpDir} \
        ~{sep=" " fastq_command_line} \
        --ref ~{ref} \
        ~{"--knownSites " + inputKnownSitesVCF + " --out-recal-file " + outbase + ".pb.BQSR-REPORT.txt"} \
        --out-bam ~{outbase}.pb.bam \
        --low-memory
    }

    output {
        File outputBAM = "~{outbase}.pb.bam"
        File outputBAI = "~{outbase}.pb.bam.bai"
        File? outputBQSR = "~{outbase}.pb.BQSR-REPORT.txt"
    }

    runtime {
        docker: docker
        acceleratorType: "nvidia-tesla-t4"
        acceleratorCount: 4
        cpu: 48
        memory: "192 GiB"
    }
}

workflow ClaraParabricks_fq2bam {

    input {
        Array[FastqPair] fastq_pairs

        File? inputKnownSitesVCF
        File inputRefTarball

        String docker = "nvcr.io/nvidia/clara/nvidia_clara_parabricks_amazon_linux:4.1.1-1"

        String ecr_registry
        String aws_region

    }
    
    scatter (fq_pair in fastq_pairs){
        call parse_inputs {
            input: 
                fq_pair=fq_pair
        }
    }

    call fq2bam {
        input:
            fastq_pairs=fastq_pairs,
            fastq_command_line=parse_inputs.command_line,
            inputKnownSitesVCF=inputKnownSitesVCF,
            inputRefTarball=inputRefTarball,
            docker=docker
    }

    output {
        File outputBAM = fq2bam.outputBAM
        File outputBAI = fq2bam.outputBAI
        File? outputBQSR = fq2bam.outputBQSR
    }

    meta {
        Author: "Nvidia Clara Parabricks"
    }
}