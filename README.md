# Implementation of the script to automatically create version tags

In the software product development process, testing is one of the most important steps, and in companies with a number of teams working together, in order to have smooth release process, a special test environment is considered for each team.

The common environment update process is like this:

- Merging changes with test branch
- Creating a tag version on gitlab/github
- Running CI/CD processes to deploy changes

In this article, I want to focus on the second stage of this process, all the stages from the time we create tag until the release happens are automated with the help of CI/CD, but the stage of creating a new tag is done completely manually by the developers themselves, which It is relatively simple but full of errors; So I found and implemented a solution to automate this step and I want to share it with you.


## Definition

In order to expect that the new tag version works properly and updates our environment, we divided it into two parts:
- The first part: showing the version of the tag (SemVer)
- The second part: specifying the name of the environment

For example, if we want to update the environment of **team-one** with a **patch** version and the current version is **1.1.0**, the tag we use should be like this:
`1.1.1-team-one`

The manual tagging process was as follows:

- Opening gitlab/github
- Navigating to tags page
- Searching for the name of our environment to see what version the last tag was created with
- Complete and submitting the new tag form based on the information of the previous step

### The pains
- It takes time to create a tag (compared to automatic mode).
- Creating an unwanted context-switch to the GitLab/Github environment
- Putting the wrong version in the tag, which caused the environment to not be updated, and finding out about this happened after deployment and testing, and it took a lot of time from the team.
- Putting the wrong environment name in the tag, which caused the pipeline to fail, and to fix the problem, the tag had to be created again.


## The solution
In order to solve these problems and eliminate human errors, I decided to write a script with which we can update any environment we want in the shortest time and automatically; Something that is both easy and fast to work with and error-free.

In general, all the steps I mentioned above to create a tag were summarized in this one line after implementing the solution, and the tagging time was reduced to 3 seconds, and the error was definitely prevented:

```
./tagGenerator.sh team-two patch
```
By executing this command, the **team-two** environment will be updated with a **patch** version compared to its previous version.

In the following, I will explain step by step how to implement this script.


## Implementation

First, we create an **sh** file in the root of our project or anywhere else, I tend to name it **tagGenerator.sh** and locate it is root of the project.

We put this code in the first line of our script:

```
#!/bin/bash
```

In order for our file to have the necessary and sufficient **permissions** to run, we must execute this command in the terminal:
```
chmod +x tagGenerator
```

Now we have to define our constants:

- The list of environments that we want to tag
  ```
  instances=("team-one" "team-two")
  ```

- The list of the type of version we want to update
  ```
  versions=("patch" "minor" "major")
  ```

Since we are going to work with tags, we need to have all remote tags, so we add this line:
```
git fetch --tags
```

As we said, our tags consist of two parts, one is the name of the `environment` and the other is the `version`. For the first part, we take input and validate it based on the constants we defined above, 
and for the second part, we take the type of version (for example, patch) as input.

We have two ways to use our script
- We give it input
- We choose from the list of options shown to us

So, to be able to have these two together, we add the following codes:

```
# Function to display select box for instances
select_instance_name() {
        echo "Please select an instance name:"
        select instance_name in "${instances[@]}" 
        do
        if [[ -n $instance_name ]]; then
                echo "You have selected: $instance_name"
                break
        else
                echo "Invalid selection. Please try again."
        fi
        done
}
```

```
# Function to display select box for versions
select_version() {
        echo "Please select version:"
        select version in "${versions[@]}"
        do
        if [[ -n $version ]]; then
                echo "You have selected: $version"
                break
        else
                echo "Invalid selection. Please try again."
        fi
        done
}
```

_This section is for getting the name of the environment as an input from the outside and validating it, if the input is not passed, the list of selectable options will be displayed:_
```
# Get INSTANCE name from input and validate, or show select box
if [ -n "$1" ]; then
if ! grep -q "${1}" <<< "${instances[*]}" then
        echo "Invalid instance name"
        exit 1
else
        instance_name=$1
fi
else
        select_instance_name
fi
```

_This part is for getting the version as an input from outside and validating it, if the input is not passed, the list of selectable options will be displayed:_
```
# Get VERSION from input and validate, or show select box
if [ -n "$2" ]; then
if ! grep -q "${2}" <<< "${versions[*]}" then
        echo "Invalid version"
        exit 1
else
        version=$2
fi
else
        select_version
fi
```

So far, we have received the inputs and we are ready to create a new tag, so we need to find the last tag of the environment we want to update.

The following code is used to find the **latest version tag** on the desired environment:
```
# Find the latest tag containing the INSTANCE
latest_tag=$(git tag --list "*$instance_name" --sort=-creatordate | sort -Vr | head -n 1)
if [ -z "$latest_tag" ]; then
        echo "No tags containing the instance name '$instance_name' found."
        exit 1
fi
        echo "Latest tag: $latest_tag"
```

We add this function to create a new version and use it:
```
# Function to increment the version
increment_version() {
        local last_version=$1
        local keyword=$2
        local semantic_version=$3
        IFS='-' read -r -a array <<< "$last_version"
        IFS='.' read -r -a parts <<< "${array[0]}"
        if [ "$semantic_version" = "major" ]; then
                new_version="$((parts[0] + 1)).0.0-$keyword"
        fi
        if [ "$semantic_version" = "minor" ]; then
                new_version="${parts[0]}.$((parts[1] + 1)).0-$keyword"
        fi
        if [ "$semantic_version" = "patch" ]; then
                new_version="${parts[0]}.${parts[1]}.$((parts[2] + 1))-$keyword"
        fi
        echo "$new_version"
}
```
```
# Version increment
new_tag=$(increment_version "$latest_tag" "$instance_name" "$version")
```

Finally, the new tag is ready to be worn, but the work does not fail and we get a confirmation for wearing it.
```
# Confirmation on creating and pushing tag
read -p "New tag is $new_tag ,Are you sure? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
        then
        exit 1
fi
echo "Latest tag: $latest_tag"
git tag "$new_tag"
git push origin "$new_tag"
```

And here we are done with the script.

## Consideration
Before we found this script, we were tagging versions manually, and the same human errors that were mentioned above caused two groups in the separation, for example, we had versions in this way in the list of our environments.
`v1.1.1-team-one`
and
`1.1.1-team-one`
And this caused `tagGenerator` to not be able to find the latest version correctly because of the **v** at the beginning of the tag, that's why I suggest that before using the script,
choose one of the two types of versioning above and `delete` all other tags that are outside the existing structure from both the remote and the local of all the people who work on the project so that the script can recognize your latest version correctly.

The command that can be used to remove defective tags from the local:
```
git tag -d v1.1.1-team-one v.1.1.0-team-one
```
The command that can be used to remove defective tags from the remote:
```
git push -d  v1.1.1-team-one v.1.1.0-team-one
```

## Finally
In this way, we were able to automate the entire process of updating our test environments, and with this, the speed of this work has increased to a very good extent, and human errors have been completely eliminated.
