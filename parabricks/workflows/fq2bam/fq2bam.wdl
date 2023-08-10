version 1.0
# Copyright 2021 NVIDIA CORPORATION & AFFILIATES

task fq2bam {
    input {
        File inputFASTQ_1
        File inputFASTQ_2
        Boolean? gvcfMode

        String readGroup_sampleName = "SAMPLE"
        String readGroup_libraryName = "LIB1"
        String readGroup_ID = "RG1"
        String readGroup_platformName = "ILLUMINA"
        String readGroup_PU = "unit1"

        File? inputKnownSitesVCF
        Boolean use_best_practices = false

        File inputRefTarball

        String? pbPATH = "pbrun"
        String? tmpDir = "tmp_fq2bam"

        String docker
    }

    String best_practice_args = if use_best_practices then "--bwa-options \" -Y -K 100000000 \" " else ""
    String rgID = if readGroup_sampleName == "SAMPLE" then readGroup_ID else readGroup_sampleName + "-" + readGroup_ID
    String ref = basename(inputRefTarball, ".tar")
    String outbase = basename(basename(basename(basename(inputFASTQ_1, ".gz"), ".fastq"), ".fq"), "_1")

    command {
        set -e
        set -x
        set -o pipefail
        mkdir -p ~{tmpDir} && \
        time tar xf ~{inputRefTarball} && \
        time ~{pbPATH} fq2bam \
        --tmp-dir ~{tmpDir} \
        --in-fq ~{inputFASTQ_1} ~{inputFASTQ_2} \
        "@RG\tID:~{rgID}\tLB:~{readGroup_libraryName}\tPL:~{readGroup_platformName}\tSM:~{readGroup_sampleName}\tPU:~{readGroup_PU}" \
        ~{best_practice_args} \
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
        memory: "192GB"
    }
}

workflow ClaraParabricks_fq2bam {

    input {
        File inputFASTQ_1
        File inputFASTQ_2
        Boolean? gvcfMode 

        String? readGroup_sampleName = "SAMPLE"
        String? readGroup_libraryName = "LIB1"
        String? readGroup_ID = "RG1"
        String? readGroup_platformName = "ILMN"
        String? readGroup_PU = "Barcode1"

        File? inputKnownSitesVCF
        Boolean? use_best_practices

        File inputRefTarball

        String pbPATH = "pbrun"
        String tmpDir = "tmp_fq2bam"

        String ecr_registry
        String aws_region

    }

    String docker = ecr_registry + "/parabricks:omics"
    
    call fq2bam {
        input:
            inputFASTQ_1=inputFASTQ_1,
            inputFASTQ_2=inputFASTQ_2,
            gvcfMode=gvcfMode,
            readGroup_sampleName=readGroup_sampleName,
            readGroup_libraryName=readGroup_libraryName,
            readGroup_ID=readGroup_ID,
            readGroup_platformName=readGroup_platformName,
            readGroup_PU=readGroup_PU,
            inputKnownSitesVCF=inputKnownSitesVCF,
            use_best_practices=use_best_practices,
            inputRefTarball=inputRefTarball,
            pbPATH=pbPATH,
            tmpDir=tmpDir,
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