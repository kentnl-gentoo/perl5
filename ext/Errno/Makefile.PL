use ExtUtils::MakeMaker;

WriteMakefile(
    NAME	 => 'Errno',
    VERSION_FROM => 'Errno_pm.PL',
    PL_FILES	 => {'Errno_pm.PL'=>'Errno.pm'},
    PM		 => {'Errno.pm' => '$(INST_LIBDIR)/Errno.pm'},
    'clean'	 => {FILES => 'Errno.pm'},
);
