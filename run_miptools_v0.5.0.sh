#!/usr/bin/env bash
ulimit -n $(ulimit -Hn)
newhome=$(pwd -P)
cd $newhome
mip_version="v0.5.0"
check_for_sif(){
    if [[ ! -f $miptools_sif ]]; then
        echo ""
        echo "error: the path to the sif in the config file cannot be found, please check on it"
        exit
    fi
    if [[ ! $miptools_sif == *"miptools_$mip_version"*  ]]; then
        echo ""
        echo "it looks like you do not have miptools_v0.5.0.sif selected in your config file"
        echo "please edit the config file to choose the correct version for this runscript"
        echo "if you do not have access to one you can download it by running the following command"
        echo "singularity pull docker://csimkin/miptools:v0.5.0"
        exit
    fi
}
# import variables from yaml
yml (){
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

# remove whitespace from variables
rmwt () {
   no_hash=$(echo -e $1 | sed -e 's/\#.*$//')
   echo -e $no_hash | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

ready_to_quit=false
main_menu (){
    echo ""
    echo "Choose one of the following options"
    PS3='Choose an option: '
    options=("edit config" "run wrangler" "check run stats" \
                "variant calling" "start jupyter" "Quit" \
    )
    select opt in "${options[@]}"
    do
        case $opt in
            "edit config")
                ./micro config_$mip_version.yaml
                eval $(yml config*.yaml)
                break
                ;;
            "run wrangler")
                eval $(yml config_$mip_version.yaml)
                check_for_sif
                mkdir -p $(rmwt $wrangler_folder)
                singularity run \
                    --app wrangler \
                    -B $(rmwt $project_resources):/opt/project_resources \
                    -B $(rmwt $wrangler_folder):/opt/user/wrangled_data \
                    -B $(rmwt $(dirname $input_sample_sheet)):/opt/input_sample_sheet_directory \
                    -B $(rmwt $fastq_dir):/opt/fastq_dir \
                    -B $newhome:/opt/config \
                    $miptools_sif \
                    -c $general_cpu_count
                break
                ;;
            "check run stats")
                eval $(yml config_$mip_version.yaml)
                check_for_sif
                mkdir -p $(rmwt $variant_calling_folder)
                singularity run \
                    --app check_run_stats \
                    -B $(rmwt $project_resources):/opt/project_resources \
                    -B $(rmwt $species_resources):/opt/species_resources \
                    -B $(rmwt $wrangler_folder):/opt/user/wrangled_data \
                    -B $(rmwt $variant_calling_folder):/opt/user/stats_and_variant_calling \
                    -B $newhome:/opt/config \
                    $miptools_sif \
                    -c $general_cpu_count
                break
                ;;
            "variant calling")
                eval $(yml config_$mip_version.yaml)
                check_for_sif
                mkdir -p $(rmwt $variant_calling_folder)
                singularity run \
                    --app variant_calling \
                    -B $(rmwt $project_resources):/opt/project_resources \
                    -B $(rmwt $species_resources):/opt/species_resources \
                    -B $(rmwt $wrangler_folder):/opt/user/wrangled_data \
                    -B $(rmwt $variant_calling_folder):/opt/user/stats_and_variant_calling \
                    -B $newhome:/opt/config \
                    $miptools_sif \
                    -c $general_cpu_count \
                    -f $freebayes_cpu_count
                break
                ;;
            "start jupyter")
                eval $(yml config_$mip_version.yaml)
                check_for_sif
                mkdir -p $(rmwt $variant_calling_folder)
                mkdir -p $(rmwt $wrangler_folder)
                if [ -z "$prevalence_metadata" ]; then # don't include prevalence data if user has left it blank
                singularity_bindings="
                    -B $(rmwt $project_resources):/opt/project_resources
                    -B $(rmwt $species_resources):/opt/species_resources
                    -B $(rmwt $wrangler_folder):/opt/user/wrangled_data
                    -B $(rmwt $variant_calling_folder):/opt/user/stats_and_variant_calling
                    -B $newhome:/opt/config"
                else
                singularity_bindings="
                    -B $(rmwt $project_resources):/opt/project_resources
                    -B $(rmwt $species_resources):/opt/species_resources
                    -B $(rmwt $wrangler_folder):/opt/user/wrangled_data
                    -B $(rmwt $variant_calling_folder):/opt/user/stats_and_variant_calling
                    -B $(rmwt $prevalence_metadata):/opt/user/prevalence_metadata
                    -B $newhome:/opt/config"
                fi
                singularity run \
                    --app jupyter \
                    $singularity_bindings \
                    $miptools_sif \
                    -d /opt/user
                break
                ;;
            "Quit")
                ready_to_quit=true
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done
}

while [ $ready_to_quit = false ];
do
    main_menu
done
