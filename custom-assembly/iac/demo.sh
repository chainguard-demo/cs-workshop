#! env bash
. ../../base.sh

ORGANIZATION="cs-ttt-demo.dev"

# Check we have the required tools installed to run the script
cmds="
  yq
"
missing_cmds=""
for cmd in ${cmds}; do
  if ! command -v "${cmd}" &> /dev/null; then
    missing_cmds+="${cmd} "
  fi
done
if [[ -n "${missing_cmds}" ]]; then
  echo "Missing required commands: ${missing_cmds}" >&2
  exit 1
fi

# Set the demo back to its initial state 
git checkout HEAD images
./postsubmit.sh "${ORGANIZATION}"

clear

banner "We have two images in the 'images/' directory. One for python, another for node."
pe "ls -l images/"
pe "cat images/custom-iac-demo-node.yaml"
pe "cat images/custom-iac-demo-python.yaml"

banner "Let's try adding 'curl' to our custom node image. First, let's check it exists in the private APK repo."
pe "curl -sSf -u \"_token:\$(chainctl auth token --audience apk.cgr.dev)\" \"https://apk.cgr.dev/${ORGANIZATION}/x86_64/APKINDEX.tar.gz\" | tar -xOz APKINDEX | grep '^P:curl$'"

banner "Next, let's add it to the file and run the presubmit checks."
pe "yq -i '.custom_overlay.contents.packages += [\"curl\"]' images/custom-iac-demo-node.yaml"
pe "git diff images/custom-iac-demo-node.yaml"
pe "./presubmit.sh ${ORGANIZATION}"

banner "If we add an invalid package to one of the files, the presubmit check should fail."
pe "yq -i '.custom_overlay.contents.packages += [\"foobar\"]' images/custom-iac-demo-python.yaml"
pe "cat images/custom-iac-demo-python.yaml"
pe "./presubmit.sh ${ORGANIZATION}"
pe "git checkout HEAD images/custom-iac-demo-python.yaml"

banner "Check that the presubmit checks are still passing."
pe "./presubmit.sh ${ORGANIZATION}"

banner "Now we can apply the changes."
pe "./postsubmit.sh ${ORGANIZATION}"

banner "Running the postsubmit again should be a no-op."
pe "./postsubmit.sh ${ORGANIZATION}"
