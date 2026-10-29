# Source this to configure the step2-cg builds from your chainctl session.
# Both the .npmrc and CGR_TOKEN expire with the session, about an hour.
chainctl auth configure-npm
echo '//libraries.cgr.dev/javascript/:always-auth=true' >> .npmrc  # Yarn Classic needs this
export CGR_TOKEN=$(chainctl auth token --audience libraries.cgr.dev)
