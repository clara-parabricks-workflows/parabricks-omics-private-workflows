version 1.0

import "fq2bam.wdl" as ToBam

task deepvariant {
    input {
        File inputBAM
        File inputBAI
        File inputRefTarball
        String pbPATH = "pbrun"
        String docker
        Boolean gvcfMode = false
    }

    String ref = basename(inputRefTarball, ".tar")
    String localTarball = basename(inputRefTarball)
    String outbase = basename(inputBAM, ".bam")

    String outVCF = outbase + ".deepvariant" + (if gvcfMode then '.g' else '') + ".vcf"

    command {
        mv ~{inputRefTarball} ${localTarball} && \
        time tar xvf ~{localTarball} && \
        time ${pbPATH} deepvariant \
        ~{if gvcfMode then "--gvcf " else ""} \
        --ref ${ref} \
        --in-bam ${inputBAM} \
        --out-variants ~{outVCF} 
    }

    output {
        File deepvariantVCF = "~{outVCF}"
    }
    
    runtime {
        docker: docker
        acceleratorType: "nvidia-tesla-t4"
        acceleratorCount: 4
        cpu: 48
        memory: "192GB"
    }
}

workflow ClaraParabricks_Germline {
    input {
        File inputFASTQ_1
        File inputFASTQ_2
        File inputRefTarball
        String pbPATH = "pbrun"
        String tmpDir_fq2bam = "tmp_fq2bam"

        ## DeepVariant Args
        Boolean gvcfMode = false

        ## Fq2bam Args 
        String? readGroup_sampleName = "SAMPLE"
        String? readGroup_libraryName = "LIB1"
        String? readGroup_ID = "RG1"
        String? readGroup_platformName = "ILMN"
        String? readGroup_PU = "Barcode1"
        File? inputKnownSitesVCF
        Boolean? use_best_practices

        String ecr_registry
        String aws_region
    }

    String docker = "nvcr.io/nvidia/clara/nvidia_clara_parabricks_amazon_linux:4.1.1-1"

    call ToBam.fq2bam as fq2bam {
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
            tmpDir=tmpDir_fq2bam,
            docker=docker
    }

    call deepvariant {
        input:
            inputBAM=fq2bam.outputBAM,
            inputBAI=fq2bam.outputBAI,
            inputRefTarball=inputRefTarball,
            pbPATH=pbPATH,
            gvcfMode=gvcfMode,
            docker=docker
    }

    output {
        File deepvariantVCF = deepvariant.deepvariantVCF
        File outputBAM = fq2bam.outputBAM
        File outputBAI = fq2bam.outputBAI
        File? outputBQSR = fq2bam.outputBQSR
    }

    meta {
        Author: "Nvidia Clara Parabricks"
    }
}