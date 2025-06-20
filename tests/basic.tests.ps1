Describe 'Basic Functionality Tests' {
    It 'should return true for a valid condition' {
        $result = $true
        $result | Should -Be $true
    }

    It 'should return false for an invalid condition' {
        $result = $false
        $result | Should -Be $false
    }
}