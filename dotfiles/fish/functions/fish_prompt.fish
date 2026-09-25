function fish_prompt

    # variables
    set returncode $status

    set -l git_branch (git symbolic-ref --short HEAD 2> /dev/null)
    set -l branch_length (string length $git_branch)

    # display
    set_color blue
    echo -n (prompt_pwd)
    set_color normal

    if test "$branch_length" != ''
        echo -n " • ("
        set_color red
        echo -n $git_branch
        set_color normal
        echo -n ")"
    end

    if test $returncode != 0
        echo -n " • ("
        set_color red
        echo -n $returncode
        set_color normal
        echo -n ")"
    end

    set_color normal
    echo -n " >> "
end
