
##########################################
# Load local profile if available        #
##########################################
if test -e "$HOME/.profile"; then
  . "$HOME/.profile"
fi

##########################################
# Set the proper JAVA_HOME               #
##########################################
arch=$(arch)
if [ "$arch" = "aarch64" ]; then
    export JAVA_HOME=$JAVA_HOME_ARM
elif [ "$arch" = "x86_64" ]; then
    export JAVA_HOME=$JAVA_HOME_AMD
fi
