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
    }

    output {
        File fastq_1_wdl_arr = fq_pair.fastq_1
        File fastq_2_wdl_arr = fq_pair.fastq_2
        String rg_wdl_arr = fq_pair.read_group
    }

    # TODO: Does this need to run in Docker even? Any local machine can run echo... 
    runtime {
        docker: docker
    }

    # runtime {
    #     docker: docker
    #     cpu: 4
    #     memory: "8 GiB"
    # }
}

task fq2bam {
    input {
        Array[File] fastq_1_wdl_arr
        Array[File] fastq_2_wdl_arr
        Array[String] rg_wdl_arr

        File? inputKnownSitesVCF
        File inputRefTarball

        String docker
    }
 
    String tmpDir = "tmp_fq2bam"
    String ref = basename(inputRefTarball, ".tar")
    String outbase = basename(basename(basename(basename(fastq_1_wdl_arr[0], ".gz"), ".fastq"), ".fq"), "_1")
    Int num_fq_pairs = length(fastq_1_wdl_arr)

    command <<<
        set -e
        set -x
        set -o pipefail 
        fastq_1_bash_arr=(~{sep=" " fastq_1_wdl_arr})
        fastq_2_bash_arr=(~{sep=" " fastq_2_wdl_arr})
        rg_bash_arr=('~{sep="' '" rg_wdl_arr}') 
        # DEBUG
        # echo "${#rg_bash_arr[*]}"
        # echo "${rg_bash_arr[*]}"
        # echo ${rg_bash_arr[*]}
        # printf '%s\n' "${rg_bash_arr[*]}"
        # printf '%s\n' ${rg_bash_arr[*]}
        # END DEBUG 
        for ((c=0; c<~{num_fq_pairs}; c++)); do printf '%s\n' "${fastq_1_bash_arr[$c]} ${fastq_2_bash_arr[$c]} ${rg_bash_arr[$c]}" >> in_fq_list.txt ; done ;
        mkdir -p ~{tmpDir} && \
        time tar xf ~{inputRefTarball} && \
        time pbrun fq2bam \
        --tmp-dir ~{tmpDir} \
        --in-fq-list in_fq_list.txt \
        --ref ~{ref} \
        ~{"--knownSites " + inputKnownSitesVCF + " --out-recal-file " + outbase + ".pb.BQSR-REPORT.txt"} \
        --out-bam ~{outbase}.pb.bam \
        --low-memory --x3
    >>>

    output {
        File outputBAM = "~{outbase}.pb.bam"
        File outputBAI = "~{outbase}.pb.bam.bai"
        File? outputBQSR = "~{outbase}.pb.BQSR-REPORT.txt"
    }

    runtime {
        docker: docker
    }

    # runtime {
    #     docker: docker
    #     acceleratorType: "nvidia-tesla-t4"
    #     acceleratorCount: 4
    #     cpu: 48
    #     memory: "192 GiB"
    # }
}

workflow ClaraParabricks_fq2bam {

    input {
        Array[FastqPair] fastq_pairs

        File inputRefTarball
        File? inputKnownSitesVCF

        String docker = "nvcr.io/nvidia/clara/nvidia_clara_parabricks_amazon_linux:4.1.1-1"

        # TODO: Can I get rid of these?? 
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
            fastq_1_wdl_arr=parse_inputs.fastq_1_wdl_arr,
            fastq_2_wdl_arr=parse_inputs.fastq_2_wdl_arr, 
            rg_wdl_arr=parse_inputs.rg_wdl_arr,
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