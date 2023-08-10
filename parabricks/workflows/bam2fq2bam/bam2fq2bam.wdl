# Copyright 2021 NVIDIA CORPORATION & AFFILIATES
version 1.0

import "fq2bam.wdl" as ToBam

## Convert a BAM file into a pair of FASTQ files.
task bam2fq {
    input {
        File inputBAM
        File inputBAI
        File? inputRefTarball 
        String pbPATH = "pbrun"
        String docker 
    }

    String ref = basename(inputRefTarball, ".tar")
    String outbase = basename(inputBAM, ".bam")

    command {
        ~{"tar xvf " + inputRefTarball + " && "}\
        time ~{pbPATH} bam2fq \
            --in-bam ~{inputBAM} \
            --out-prefix ~{outbase} \
            ~{"--ref " + ref} \
    }

    output {
        File outputFASTQ_1 = "${outbase}_1.fastq.gz"
        File outputFASTQ_2 = "${outbase}_2.fastq.gz"
    }

    runtime {
        docker: docker
        acceleratorType: "nvidia-tesla-t4-a10g"
        acceleratorCount: 4
        cpu: 48
        memory: "192GB"
    }
}

workflow ClaraParabricks_bam2fq2bam {
    ## Given a BAM file,
    ## extract the reads from it and realign them to a new reference genome.
    ## Expected runtime for a 30X BAM is less than 3 hours on a 4x V100 system.
    ## We recommend running with at least 32 threads and 4x V100 GPUs on Baremetal and
    ## utilizing 4x T4s on the cloud.
    input {
        File inputBAM
        File inputBAI
        File inputRefTarball
        String pbPATH = "pbrun"
        String tmpDir_fq2bam = "tmp_fq2bam"

        ## Fq2bam Args 
        String? readGroup_sampleName = "SAMPLE"
        String? readGroup_libraryName = "LIB1"
        String? readGroup_ID = "RG1"
        String? readGroup_platformName = "ILMN"
        String? readGroup_PU = "Barcode1"
        File? inputKnownSitesVCF
        Boolean? use_best_practices
        Boolean gvcfMode = false

        String ecr_registry
        String aws_region
    }

    String docker = ecr_registry + "/parabricks:omics"

    ## Run the BAM -> FASTQ conversion
    call bam2fq {
        input:
            inputBAM=inputBAM,
            inputBAI=inputBAI,
            inputRefTarball=inputRefTarball,
            pbPATH=pbPATH,
            docker=docker
    }

    ## Remap the reads from the bam2fq stage to the new reference to produce a BAM file.
    call ToBam.fq2bam as fq2bam {
        input:
            inputFASTQ_1=bam2fq.outputFASTQ_1,
            inputFASTQ_2=bam2fq.outputFASTQ_2,
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
            tmpDir=tmpDir_fq2bam,
            docker=docker
    }

    output {
        File outputFASTQ_1 = bam2fq.outputFASTQ_1
        File outputFASTQ_2 = bam2fq.outputFASTQ_2
        File outputBAM = fq2bam.outputBAM
        File outputBAI = fq2bam.outputBAI
        File? outputBQSR = fq2bam.outputBQSR
    }

    meta {
        Author: "Nvidia Clara Parabricks"
    }
}