#!/usr/bin/env bash

# The steps of publishing
# 1. Update the Conductrics.podspec file:
#		Replace version, entirely
#		Replace :tag => "pod-release-0.0.1"
# 2. git commit Conductrics.podspec -m "bump version to ${NEW_VERSION}"
# 3. git tag pod-release-${NEW_VERSION}
# 4. git push origin pod-release-${NEW_VERSION}
# 5. pod trunk push

NEW_VERSION=$1
if [ -z "${NEW_VERSION}" ]; then
	echo usage
	exit 1
fi

GIT_TAG=pod-release-$NEW_VERSION

echo Patching podspec...
sed -i -e 's/spec.version *= *"\([0-9.]*\)"/spec.version = "'"$NEW_VERSION"'"/' Conductrics.podspec
sed -i -e 's/:tag *=> *"[^"]*"/:tag => "'"$GIT_TAG"'"/' Conductrics.podspec

echo Creating $GIT_TAG...
git tag $GIT_TAG
git push origin $GIT_TAG

echo Publishing to pod repo...
pod trunk push
