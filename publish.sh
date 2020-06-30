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

echo Updating VERSION \
&& echo $NEW_VERSION > VERSION \
&& echo Patching podspec... \
&& sed -i ".bak" -e 's/spec.version *= *"\([0-9.]*\)"/spec.version = "'"$NEW_VERSION"'"/' Conductrics.podspec \
&& sed -i "" -e 's/:tag *=> *"[^"]*"/:tag => "'"$GIT_TAG"'"/' Conductrics.podspec \
&& rm Conductrics.podspec.bak \
&& echo Creating $GIT_TAG... \
&& git commit VERSION Conductrics.podspec -m "bump version to $NEW_VERSION" \
&& git tag $GIT_TAG \
&& git push origin $GIT_TAG \
&& echo Publishing to pod repo... \
&& pod trunk push \
&& echo Finished.
