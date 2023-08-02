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
        File? inputRecal
        File inputRefTarball
        String pbPATH = "pbrun"

        String tmpDir_fq2bam = "tmp_fq2bam"
        Boolean gvcfMode = false

        ## Fq2bam Runtime Args 
        File? inputKnownSitesVCF
        File? inputKnownSitesTBI

        String ecr_registry
        String aws_region
    }

    String docker = ecr_registry + "/parabricks-omics"

    call ToBam.fq2bam as fq2bam {
        input:
            inputFASTQ_1=inputFASTQ_1,
            inputFASTQ_2=inputFASTQ_2,
            inputRefTarball=inputRefTarball,
            inputKnownSitesVCF=inputKnownSitesVCF,
            inputKnownSitesTBI=inputKnownSitesTBI,
            pbPATH=pbPATH,
            tmpDir=tmpDir_fq2bam,
            pbDocker=pbDocker
    }

    call deepvariant {
        input:
            inputBAM=fq2bam.outputBAM,
            inputBAI=fq2bam.outputBAI,
            inputRefTarball=inputRefTarball,
            pbPATH=pbPATH,
            gvcfMode=gvcfMode,
            pbDocker=pbDocker
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