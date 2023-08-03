version 1.0

import "fq2bam.wdl" as ToBam

task haplotypecaller {
    input {
        File inputBAM
        File inputBAI
        File? inputRecal
        File inputRefTarball
        String pbPATH = "pbrun"
        Boolean gvcfMode = false
        Boolean useBestPractices = false
        String haplotypecallerPassthroughOptions = ""
        String annotationArgs = ""
        String? docker
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

        ## Run both fq2bam and HaplotypeCaller in gVCF mode
        Boolean gvcfMode = false

        ## Fq2bam Runtime Args 
        String? readGroup_sampleName = "SAMPLE"
        String? readGroup_libraryName = "LIB1"
        String? readGroup_ID = "RG1"
        String? readGroup_platformName = "ILMN"
        String? readGroup_PU = "Barcode1"
        File? inputKnownSitesVCF
        Boolean? use_best_practices

        ## HaplotypeCaller Runtime Args
        String? haplotypecallerPassthroughOptions
        File? inputRecal
        String? annotationArgs

        String ecr_registry
        String aws_region
    }

    String docker = ecr_registry + "/parabricks-omics"

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

    call haplotypecaller {
        input:
            annotationArgs=annotationArgs,
            inputBAM=fq2bam.outputBAM,
            inputBAI=fq2bam.outputBAI,
            inputRecal=inputRecal,
            inputRefTarball=inputRefTarball,
            pbPATH=pbPATH,
            gvcfMode=gvcfMode,
            haplotypecallerPassthroughOptions=haplotypecallerPassthroughOptions,
            docker=docker,
    }

    output {
        File haplotypecallerVCF = haplotypecaller.haplotypecallerVCF
        File outputBAM = fq2bam.outputBAM
        File outputBAI = fq2bam.outputBAI
        File? outputBQSR = fq2bam.outputBQSR
    }

    meta {
        Author: "Nvidia Clara Parabricks"
    }
}