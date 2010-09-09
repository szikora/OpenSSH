BUILDHOME = $(PWD)
OPENSSHVERSION = 5.6p1

all: package-openssh

clean: clean-openssh

clean-openssh:
	rm -rf openssh
	rm -rf compiled-openssh
	rm -f fetch-openssh build-openssh install-openssh package-openssh

clean-openssh-bin:
	rm -f openssh-$(OPENSSHVERSION).tar.gz
	rm -rf OpenSSH-$(OPENSSHVERSION).pkg
	rm -f OpenSSH-$(OPENSSHVERSION)_for_$(OSX_RELEASE).dmg

openssh-$(OPENSSHVERSION).tar.gz:
	curl -O http://ftp.belnet.be/packages/openbsd/OpenSSH/portable/$@

fetch-openssh: openssh-$(OPENSSHVERSION).tar.gz
	rm -rf openssh
	tar xzvf $^
	mv openssh-$(OPENSSHVERSION) openssh
	touch $@

build-openssh: fetch-openssh
ifeq ("$(OSX_RELEASE)","10.5")
	cd openssh && \
	LIBS="-lresolv" \
	CFLAGS="-isysroot /Developer/SDKs/MacOSX10.5.sdk -arch i386 -arch ppc7400 -mmacosx-version-min=10.5 -g" \
	LDFLAGS="-arch i386 -arch ppc7400" \
	./configure --prefix=/Library/OpenSSH  && \
	make && \
	make install-nokeys prefix=$(BUILDHOME)/compiled-openssh/Library/OpenSSH
endif
ifeq ("$(OSX_RELEASE)","10.6")
	cd openssh && \
	LIBS="-lresolv" \
	CFLAGS="-arch x86_64 -arch i386" \
	LDFLAGS="-arch x86_64 -arch i386" \
	./configure --prefix=/Library/OpenSSH  && \
	make && \
	make install-nokeys prefix=$(BUILDHOME)/compiled-openssh/Library/OpenSSH
endif
	rm -f $(BUILDHOME)/compiled-openssh/Library/OpenSSH/bin/ssh-keyscan
	rm -f $(BUILDHOME)/compiled-openssh/Library/OpenSSH/etc/ssh_host*
	rm -f $(BUILDHOME)/compiled-openssh/Library/OpenSSH/etc/sshd_config
	rm -rf $(BUILDHOME)/compiled-openssh/Library/OpenSSH/libexec
	rm -f $(BUILDHOME)/compiled-openssh/Library/OpenSSH/share/man/man1/ssh-keyscan.1
	rm -f $(BUILDHOME)/compiled-openssh/Library/OpenSSH/share/man/man5/sshd_config.5
	rm -rf $(BUILDHOME)/compiled-openssh/Library/OpenSSH/share/man/man8
	rm -rf $(BUILDHOME)/compiled-openssh/Library/OpenSSH/sbin
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSSH/bin/ssh $(BUILDHOME)/compiled-openssh/Library/OpenSSH/bin/sc-ssh
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSSH/bin/ssh-add $(BUILDHOME)/compiled-openssh/Library/OpenSSH/bin/sc-ssh-add
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSSH/bin/ssh-agent $(BUILDHOME)/compiled-openssh/Library/OpenSSH/bin/sc-ssh-agent
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSSH/bin/ssh-keygen $(BUILDHOME)/compiled-openssh/Library/OpenSSH/bin/sc-ssh-keygen
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSSH/bin/scp $(BUILDHOME)/compiled-openssh/Library/OpenSSH/bin/sc-scp
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSSH/bin/sftp $(BUILDHOME)/compiled-openssh/Library/OpenSSH/bin/sc-sftp
	rm -f $(BUILDHOME)/compiled-openssh/Library/OpenSSH/bin/slogin
	cd $(BUILDHOME)/compiled-openssh/Library/OpenSSH/bin/ && ln -s ./sc-ssh sc-slogin
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSSH/share/man/man1/ssh-add.1 $(BUILDHOME)/compiled-openssh/Library/OpenSSH/share/man/man1/sc-ssh-add.1
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSSH/share/man/man1/ssh-agent.1 $(BUILDHOME)/compiled-openssh/Library/OpenSSH/share/man/man1/sc-ssh-agent.1
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSSH/share/man/man1/ssh-keygen.1 $(BUILDHOME)/compiled-openssh/Library/OpenSSH/share/man/man1/sc-ssh-keygen.1
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSSH/share/man/man1/ssh.1 $(BUILDHOME)/compiled-openssh/Library/OpenSSH/share/man/man1/sc-ssh.1
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSSH/share/man/man1/scp.1 $(BUILDHOME)/compiled-openssh/Library/OpenSSH/share/man/man1/sc-scp.1
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSSH/share/man/man1/sftp.1 $(BUILDHOME)/compiled-openssh/Library/OpenSSH/share/man/man1/sc-sftp.1
	rm -f $(BUILDHOME)/compiled-openssh/Library/OpenSSH/share/man/man1/slogin.1
	cd $(BUILDHOME)/compiled-openssh/Library/OpenSSH/share/man/man1/ && ln -s ./sc-ssh.1 sc-slogin.1
	mkdir -p $(BUILDHOME)/compiled-openssh/usr/local/bin
	cp $(BUILDHOME)/openssh-uninstall $(BUILDHOME)/compiled-openssh/usr/local/bin
	touch $@

install-openssh: build-openssh
	cp -HR $(BUILDHOME)/compiled-openssh/Library/OpenSSH /Library
	touch $@

package-openssh: build-openssh
	/Developer/Applications/Utilities/PackageMaker.app/Contents/MacOS/PackageMaker \
	-r compiled-openssh \
	-o OpenSSH-$(OPENSSHVERSION).pkg \
	-t "OpenSSH with Smartcard support $(OPENSSHVERSION)" \
	-i org.opensc-project.mac.ssh \
	-n $(OPENSSHVERSION) \
	-g 10.4 \
	-b \
	-v \
	--no-relocate \
	-e MacOSX/$(OSX_RELEASE)/resources \
	-s MacOSX/$(OSX_RELEASE)/scripts
	rm -f OpenSSH-$(OPENSSHVERSION)_for_$(OSX_RELEASE).dmg
	hdiutil create -srcfolder OpenSSH-$(OPENSSHVERSION).pkg -volname "OpenSSH with Smartcard support for $(OSX_RELEASE)" OpenSSH-$(OPENSSHVERSION)_for_$(OSX_RELEASE).dmg
	touch $@
