# Copyright 2021 NVIDIA CORPORATION & AFFILIATES
version 1.0

import "fq2bam.wdl" as ToBam

## Convert a BAM file into a pair of FASTQ files.
task bam2fq {
    input {
        File inputBAM
        File inputBAI
        File? originalRefTarball = "s3://SAMPLE_DATA_BUCKET/WORKFLOW_ID/Homo_sapiens_assembly38.fasta.tar" # Required for CRAM input
        String? ref = "Homo_sapiens_assembly38.fasta" # Name of FASTA reference file, required for CRAM input
        String pbPATH = "pbrun"
        String pbDocker = "SERVICE_ACCOUNT_ID.dkr.ecr.AWS_REGION.amazonaws.com/omics/shared/clara-parabricks:4.0.0-1"
    }

    String outbase = basename(inputBAM, ".bam")

    command {
        ~{"tar xvf " + originalRefTarball + " && "}\
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
        File? inputKnownSitesVCF
        File? inputKnownSitesTBI
        File? originalRefTarball = "s3://SAMPLE_DATA_BUCKET/WORKFLOW_ID/Homo_sapiens_assembly38.fasta.tar" # for CRAM input
        String? ref = "Homo_sapiens_assembly38.fasta" # Name of FASTA reference file, required for CRAM input
        String pbPATH = "pbrun"
        String pbDocker = "SERVICE_ACCOUNT_ID.dkr.ecr.AWS_REGION.amazonaws.com/omics/shared/clara-parabricks:4.0.0-1"
        String tmpDir = "tmp_fq2bam"
    }

    if (defined(originalRefTarball)){
        ref = basename(select_first([originalRefTarball]), ".tar")
    }

    ## Run the BAM -> FASTQ conversion
    call bam2fq {
        input:
            inputBAM=inputBAM,
            inputBAI=inputBAI,
            originalRefTarball=originalRefTarball,
            ref=ref,
            pbPATH=pbPATH,
            pbDocker=pbDocker
    }

    ## Remap the reads from the bam2fq stage to the new reference to produce a BAM file.
    call ToBam.fq2bam as fq2bam {
        input:
            inputFASTQ_1=bam2fq.outputFASTQ_1,
            inputFASTQ_2=bam2fq.outputFASTQ_2,
            originalRefTarball=originalRefTarball,
            inputKnownSitesVCF=inputKnownSitesVCF,
            inputKnownSitesTBI=inputKnownSitesTBI,
            pbPATH=pbPATH,
            tmpDir=tmpDir,
            pbDocker=pbDocker
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