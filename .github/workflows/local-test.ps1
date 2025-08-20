$repo = "AndrewEhlo/test-vc-deploy-dev"
$excludeBranches = @("main", "master", "dev")
$dryRun = 'true'
$authorForRemove = "Andrew" # "vc-ci"
$retentionDays = 0
$targetBranch = "vcptcore-qa"

# Close stale PRs and remove corresponding branches
Write-Host "Closing stale PRs in $repo, removing corresponding branches. Target branch: $targetBranch, retention days: $retentionDays, author for remove: $authorForRemove"
$openPrsJson = gh pr list --repo $repo --base $targetBranch --state open --json "number,headRefName,createdAt,author,baseRefName,headRefName"
$openPrs = $openPrsJson | ConvertFrom-Json

foreach ($pr in $openPrs) {
    $branch = $pr.headRefName
    $author = $pr.author.name
    $date = [datetime]$pr.createdAt
    $daysSinceCreation = $((Get-Date) - $date).Days
    if ($daysSinceCreation -ge $retentionDays) {
        Write-Host "Closing PR #$($pr.number) for '$branch' branch (created $daysSinceCreation days ago)"
        if ($dryRun -eq 'false') {
            gh pr comment $($pr.number) --repo $repo --body "Closed by stale branch cleanup workflow"
            gh pr close $($pr.number) --repo $repo
            Write-Host "PR $($pr.number) closed"
            git push origin --delete $branch 
        }
        else {
            Write-Host "DRY RUN: gh pr comment $($pr.number) --repo $repo --body 'Closed by stale branch cleanup workflow'"
            Write-Host "DRY RUN: gh pr close $($pr.number) --repo $repo"
            Write-Host "DRY RUN: git push origin --delete $branch"
        }
    }
}
Write-Host "Done closing stale PRs and removing corresponding branches"

# Delete stale branches
Write-Host "Scanning closed pull requests in $repo to delete branches. Target branch: $targetBranch, author for remove: $authorForRemove"

# Get closed PRs using gh
$closedPrsJson = gh pr list --repo $repo --state closed --base $targetBranch --json "number,headRefName,mergedAt,author"
$closedPrs = $closedPrsJson | ConvertFrom-Json

foreach ($pr in $closedPrs) {
    $branch = $pr.headRefName
    $merged = $pr.mergedAt
    $author = $pr.author.name
    # Skip if merged (only clean closed/unmerged PRs):
    if ($null -ne $merged) {
        continue
    }

    # Skip excluded branches
    if ($excludeBranches -contains $branch) {
        Write-Host "Skipping '$branch' branch (in exclude list)"
        continue
    }

    # Skip if author is not vc-ci
    if ($author -ne $authorForRemove) {
        Write-Host "Skipping '$branch' branch (not by $authorForRemove)"
        continue
    }

    Write-Host "Deleting closed PR branch: '$branch'"
    
    # delete remote branch
    if ($dryRun -eq 'false') {
        git push origin --delete $branch
    }
    else {
        Write-Host "DRY RUN: git push origin --delete $branch"
    }
    
    if ($deleteLocal) {
        git branch -D $branch 2>$null
    }
}
Write-Host "Done deleting stale branches"