CREDS_OUTPUT=$(chainctl auth pull-token \
  --repository=javascript \
  --parent=zachary.yonash \
  --name=js-workshop-token-zachary.yonash \
  --ttl=1h \
  -o json)

export CHAINGUARD_JAVASCRIPT_IDENTITY_ID=$(echo $CREDS_OUTPUT | jq -r ".identity_id")
export CHAINGUARD_JAVASCRIPT_TOKEN=$(echo $CREDS_OUTPUT | jq -r ".token")
#export TOKEN=$(echo -n "${CHAINGUARD_JAVASCRIPT_IDENTITY_ID}:${CHAINGUARD_JAVASCRIPT_TOKEN}" | base64 -w 0)
export TOKEN="$(printf '%s' "${CHAINGUARD_JAVASCRIPT_IDENTITY_ID}:${CHAINGUARD_JAVASCRIPT_TOKEN}" | base64 | tr -d '\n')"

cat <<EOF > .npmrc
registry=https://libraries.cgr.dev/javascript/
//libraries.cgr.dev/javascript/:_auth="${TOKEN}"
EOF
