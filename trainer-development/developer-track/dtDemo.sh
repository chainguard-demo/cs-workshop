#!/bin/bash

PS3="Select item to run: "

items=("Tag History API" "chainctl images diff" "chainctl images list" "crane - list image tags" "grype - scan image" "sfyt - create SBOM for image" "cosign - download SBOM")

while true; do
    select item in "${items[@]}" Quit
    do
        case $REPLY in
            #Tag History API
            1) echo "Run $item"; 
               echo "Enter image name (i.e. jdk)"
               read -r imageName
               #echo "curl -H "Authorization: Bearer $tok" \\n  https://cgr.dev/v2/chainguard/$imageName/_chainguard/history/latest | jq"
               read tok < <(curl "https://cgr.dev/token?scope=repository:chainguard/$imageName:pull" | jq -r '.token')
               echo "Running curl -H "Authorization: Bearer ###########"  https://cgr.dev/v2/chainguard/$imageName/_chainguard/history/latest | jq"
               (curl -H "Authorization: Bearer $tok"  https://cgr.dev/v2/chainguard/$imageName/_chainguard/history/latest | jq)
               break;;
            #Chainguard - chainctl images diff   
            2) echo "Run $item"; 
               echo "Enter image 1 name and tag (i.e. jdk:latest)"
               read -r image1
               echo "Enter image 2 name and tag (i.e. jdk:latest-dev)"
               read -r image2
               echo "Running chainctl images diff cgr.dev/chainguard/$image1 cgr.dev/chainguard/$image2"
               (chainctl images diff cgr.dev/chainguard/$image1 cgr.dev/chainguard/$image2 | jq)
               break;;
            #Chainguard - chainctl images list
            3) echo "Run $item";
               echo "Enter org name (i.e. acme.com)"
               read -r orgName
               echo "Enter image repo name (i.e. python)"
               read -r imageName
               echo "Running chainctl images list --repo $imageName --parent $orgName --show-epochs"
               (chainctl images list --repo $imageName --parent $orgName --show-epochs)
               break;;
            4) echo "Run $item";
               echo "Enter image name (i.e. jdk)"
               read -r imageName 
               echo "Running crane ls -O cgr.dev/chainguard-private/$imageName"
               (crane ls -O cgr.dev/chainguard-private/$imageName)
               break;;
            5) echo "Selected item #$REPLY which means $item";
               echo "Enter image name and tag (i.e. jdk:latest)"
               read -r imageTag 
               echo "grype cgr.dev/chainguard/$imageTag"
               (grype cgr.dev/chainguard/$imageTag)
               break;;
            6) echo "Selected item #$REPLY which means $item";
               echo "Enter image name and tag (i.e. jdk:latest)"
               read -r imageName
               echo "Running syft cgr.dev/chainguard/$imageName -o syft-text "
               (syft cgr.dev/chainguard/$imageName -o syft-text)
               break;;
            7) echo "Selected item #$REPLY which means $item";
               echo "Enter image name and tag (i.e. jdk:latest)"
               read -r imageName
               echo "Running cosign download attestation cgr.dev/chainguard/$imageName | jq -r .payload | base64 -d | jq .predicate"
               (cosign download attestation cgr.dev/chainguard/$imageName | jq -r .payload | base64 -d | jq .predicate)
               break;;
            $((${#items[@]}+1))) echo "Exiting..."; break 2;;
            *) echo "Ooops - unknown choice $REPLY"; break;
        esac
    done
done
