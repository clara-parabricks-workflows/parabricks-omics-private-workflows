version 1.0

import "fq2bam.wdl" as ToBam

task haplotypecaller {
    input {
        File inputBAM
        File inputBAI
        File? inputRecal
        File inputRefTarball = "s3://SAMPLE_DATA_BUCKET/WORKFLOW_ID/Homo_sapiens_assembly38.fasta.tar"
        String pbPATH = "pbrun"
        File? intervalFile
        Boolean gvcfMode = false
        Boolean useBestPractices = false
        String haplotypecallerPassthroughOptions = ""
        String annotationArgs = ""
        String? pbDocker
    }

    String outbase = basename(inputBAM, ".bam")
    String localTarball = basename(inputRefTarball)
    String ref = basename(inputRefTarball, ".tar")

    String outVCF = outbase + ".haplotypecaller" + (if gvcfMode then '.g' else '') + ".vcf"

    String quantization_band_stub = if useBestPractices then " -GQB 10 -GQB 20 -GQB 30 -GQB 40 -GQB 50 -GQB 60 -GQB 70 -GQB 80 -GQB 90 " else ""
    String quantization_qual_stub = if useBestPractices then " --static-quantized-quals 10 --static-quantized-quals 20 --static-quantized-quals 30" else ""
    String annotation_stub_base = if useBestPractices then "-G StandardAnnotation -G StandardHCAnnotation" else annotationArgs
    String annotation_stub = if useBestPractices && gvcfMode then annotation_stub_base + " -G AS_StandardAnnotation " else annotation_stub_base

    command {
        mv ~{inputRefTarball} ${localTarball} && \
        time tar xvf ~{localTarball} && \
        time ~{pbPATH} haplotypecaller \
        --in-bam ~{inputBAM} \
        --ref ~{ref} \
        --out-variants ~{outVCF} \
        ~{"--in-recal-file " + inputRecal} \
        ~{if gvcfMode then "--gvcf " else ""} \
        ~{"--haplotypecaller-options " + '"' + haplotypecallerPassthroughOptions + '"'} \
        ~{annotation_stub} \
        ~{quantization_band_stub} \
        ~{quantization_qual_stub} 
    }

    output {
        File haplotypecallerVCF = "~{outVCF}"
    }

    runtime {
        acceleratorType: "nvidia-tesla-t4"
        acceleratorCount: 4
        cpu: 48
        memory: "192GB"
    }
}

task deepvariant {
    input {
        File inputBAM
        File inputBAI
        File inputRefTarball = "s3://SAMPLE_DATA_BUCKET/WORKFLOW_ID/Homo_sapiens_assembly38.fasta.tar"
        String pbPATH = "pbrun"
        String? pbDocker
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
        File inputRefTarball = "s3://SAMPLE_DATA_BUCKET/WORKFLOW_ID/Homo_sapiens_assembly38.fasta.tar"
        String pbPATH = "pbrun"

        String tmpDir_fq2bam = "tmp_fq2bam"
        String pbDocker = "SERVICE_ACCOUNT_ID.dkr.ecr.AWS_REGION.amazonaws.com/omics/shared/clara-parabricks:4.0.0-1"
        Boolean gvcfMode = false

        ## Fq2bam Runtime Args 
        File? inputKnownSitesVCF
        File? inputKnownSitesTBI
    }

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