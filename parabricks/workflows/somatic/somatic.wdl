version 1.0
# Copyright 2021 NVIDIA CORPORATION & AFFILIATES

task somatic {
    input {
        File tumorInputFASTQ_1
        File tumorInputFASTQ_2
        File normalInputFASTQ_1
        File normalInputFASTQ_2
        File inputRefTarball

        String tumorReadGroup_sampleName = "SAMPLE_TUMOR"
        String? tumorReadGroup_libraryName = "LIB1"
        String tumorReadGroup_ID = "RG1"
        String? tumorReadGroup_platformName = "ILLUMINA"
        String? tumorReadGroup_PU = "unit1"

        String normalReadGroup_sampleName = "SAMPLE_NORMAL"
        String? normalReadGroup_libraryName = "LIB1"
        String normalReadGroup_ID = "RG1"
        String? normalReadGroup_platformName = "ILLUMINA"
        String? normalReadGroup_PU = "unit1"

        File? inputKnownSitesVCF
        File? inputKnownSitesTBI
        Boolean use_best_practices = false

        String pbPATH = "pbrun"
        String docker
        String tmpDir = "tmp_fq2bam"

    }

    String best_practice_args = if use_best_practices then "--bwa-options \" -Y -K 100000000 \" " else ""

    String tumorRgID = if tumorReadGroup_sampleName == "SAMPLE_TUMOR" then tumorReadGroup_ID else tumorReadGroup_sampleName + "-" + tumorReadGroup_ID
    String normalRgID = if normalReadGroup_sampleName == "SAMPLE_NORMAL" then normalReadGroup_ID else normalReadGroup_sampleName + "-" + normalReadGroup_ID

    String ref = basename(inputRefTarball, ".tar")
    String tumorOutbase = basename(basename(basename(basename(tumorInputFASTQ_1, ".gz"), ".fastq"), ".fq"), "_1")
    String normalOutbase = basename(basename(basename(basename(normalInputFASTQ_1, ".gz"), ".fastq"), ".fq"), "_1")
    command {
        set -e
        set -x
        set -o pipefail
        mkdir -p ~{tmpDir} && \
        time tar xf ~{inputRefTarball} && \
        time ~{pbPATH} somatic \
        --tmp-dir ~{tmpDir} \
        --in-tumor-fq ~{tumorInputFASTQ_1} ~{tumorInputFASTQ_2} \
        --out-tumor-bam ~{tumorOutbase}.pb.bam \
        --in-normal-fq ~{normalInputFASTQ_1} ~{normalInputFASTQ_2} \
        --out-normal-bam ~{normalOutbase}.pb.bam \
        ~{best_practice_args} \
        --ref ~{ref} \
        ~{"--knownSites " + inputKnownSitesVCF + " --out-recal-file " + tumorOutbase + ".pb.BQSR-REPORT.txt"} \
        --out-vcf ~{tumorOutbase}.vcf
    }

    output {
        File tumorOutputBAM = "~{tumorOutbase}.pb.bam"
        File tumorOutputBAI = "~{tumorOutbase}.pb.bam.bai"
        File normalOutputBAM = "~{normalOutbase}.pb.bam"
        File normalOutputBAI = "~{normalOutbase}.pb.bam.bai"
        File outputVCF = "~{tumorOutbase}.vcf"
        File? outputBQSR = "~{tumorOutbase}.pb.BQSR-REPORT.txt"
    }

    runtime {
        docker: docker
        acceleratorType: "nvidia-tesla-t4"
        acceleratorCount: 4
        cpu: 48
        memory: "192GB"
    }
}

workflow ClaraParabricks_somatic {

    input {
        File tumorInputFASTQ_1
        File tumorInputFASTQ_2
        File normalInputFASTQ_1
        File normalInputFASTQ_2
        File inputRefTarball

        String tumorReadGroup_sampleName = "SAMPLE_TUMOR"
        String? tumorReadGroup_libraryName = "LIB1"
        String tumorReadGroup_ID = "RG1"
        String? tumorReadGroup_platformName = "ILLUMINA"
        String? tumorReadGroup_PU = "unit1"

        String normalReadGroup_sampleName = "SAMPLE_NORMAL"
        String? normalReadGroup_libraryName = "LIB1"
        String normalReadGroup_ID = "RG1"
        String? normalReadGroup_platformName = "ILLUMINA"
        String? normalReadGroup_PU = "unit1"

        File? inputKnownSitesVCF
        File? inputKnownSitesTBI
        String pbPATH = "pbrun"
        String docker
        String tmpDir = "tmp_fq2bam"
    }
    
    call somatic {
        input:
            tumorInputFASTQ_1=tumorInputFASTQ_1,
            tumorInputFASTQ_2=tumorInputFASTQ_2,
            normalInputFASTQ_1=normalInputFASTQ_1,
            normalInputFASTQ_2=normalInputFASTQ_2,
            inputRefTarball=inputRefTarball,
            inputKnownSitesVCF=inputKnownSitesVCF,
            inputKnownSitesTBI=inputKnownSitesTBI,
            pbPATH=pbPATH,
            tumorReadGroup_sampleName=tumorReadGroup_sampleName,
            tumorReadGroup_libraryName=tumorReadGroup_libraryName,
            tumorReadGroup_ID=tumorReadGroup_ID,
            tumorReadGroup_platformName=tumorReadGroup_platformName,
            tumorReadGroup_PU=tumorReadGroup_PU,
            normalReadGroup_sampleName=normalReadGroup_sampleName,
            normalReadGroup_libraryName=normalReadGroup_libraryName,
            normalReadGroup_ID=normalReadGroup_ID,
            normalReadGroup_platformName=normalReadGroup_platformName,
            normalReadGroup_PU=normalReadGroup_PU,
            docker=docker,
            tmpDir=tmpDir
    }

    output {
        File tumorOutputBAM=somatic.tumorOutputBAM
        File tumorOutputBAI=somatic.tumorOutputBAI
        File normalOutputBAM=somatic.normalOutputBAM
        File normalOutputBAI=somatic.normalOutputBAI
        File outputVCF=somatic.outputVCF
        File? outputBQSR=somatic.outputBQSR
    }

    meta {
        Author: "Nvidia Clara Parabricks"
    }
}