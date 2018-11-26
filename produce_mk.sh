find . -type f -name "*.a" > a.txt
find . -type f -name "*.so" > so.txt
find . -type f -name "*.h" -exec dirname {} \; > hh.txt
uniq hh.txt > h.txt
rm hh.txt
find . -type f -name "*.cpp" > cpp.txt

g++ -x c++ -std=c++11 - << EOF

#include <fstream>
#include <string>

#include <string.h>

using std::ofstream;
using std::ifstream;
using std::ios_base;
using std::string;

string gettime(void)
{
    time_t timetTime;
    struct tm *pTmTime;
    char   szTime[1000] = {0};

    timetTime = time(NULL);

    pTmTime = localtime(&timetTime);
    snprintf(szTime, sizeof(szTime)-1,
     "################################################################\nauto created by chijilyb's autojnitool: %d-%02d-%02d %02d:%02d:%02d\n################################################################\n\n",
        pTmTime->tm_year+1900,
        pTmTime->tm_mon+1,
        pTmTime->tm_mday,
        pTmTime->tm_hour,
        pTmTime->tm_min,
        pTmTime->tm_sec);

    return szTime;
}

void produce_application_mk(void)
{
    static const char* application_mk = R"==(APP_ABI := armeabi-v7a
APP_PLATFORM := android-21)==";

    ofstream out("Application.mk", ios_base::binary);
    out.write(application_mk, strlen(application_mk));
}

#define chijilyb_tag_libname "chijilyb_tag_libname"
#define chijilyb_tag_libpath "chijilyb_tag_libpath"
auto chijilyb_tag_libname_len = strlen(chijilyb_tag_libname);
auto chijilyb_tag_libpath_len = strlen(chijilyb_tag_libpath);

void produce_prebuild_static_lib(ofstream& out, const string& static_lib_path)
{
    static const char* local_path = R"==(LOCAL_PATH := \$(call my-dir))==";
    out.write(local_path, strlen(local_path));

    static const char* prebuild_static = R"==(

include \$(CLEAR_VARS)
LOCAL_MODULE     			:= chijilyb_tag_libname
LOCAL_SRC_FILES 			:= \$(LOCAL_PATH)chijilyb_tag_libpath
include \$(PREBUILT_STATIC_LIBRARY)
################################################################)==";

    ifstream in(static_lib_path.c_str(), ios_base::binary);
    string str;

    while(getline(in, str))
    {
        string libpath = str.substr(1);
        string libname = str.substr(str.rfind("/lib") + strlen("/lib"),
                                    str.size() - str.rfind("/lib") - strlen("/lib") - strlen(".a"));

        string libprebuild = prebuild_static;

        libprebuild.replace(libprebuild.find(chijilyb_tag_libname, 0), chijilyb_tag_libname_len, libname);
        libprebuild.replace(libprebuild.find(chijilyb_tag_libpath, 0), chijilyb_tag_libpath_len, libpath);

        out.write(libprebuild.c_str(), libprebuild.size());
    }
}

void produce_prebuild_shared_lib(ofstream& out, const string& shared_lib_path)
{
    static const char* prebuild_shared = R"==(

include \$(CLEAR_VARS)
LOCAL_MODULE    			:= chijilyb_tag_libname
LOCAL_SRC_FILES 			:= \$(LOCAL_PATH)chijilyb_tag_libpath
include \$(PREBUILT_SHARED_LIBRARY)
################################################################)==";

    ifstream in(shared_lib_path.c_str(), ios_base::binary);
    string str;

    while(getline(in, str))
    {
        string libpath = str.substr(1);
        string libname = str.substr(str.rfind("/lib") + strlen("/lib"),
                                    str.size() - str.rfind("/lib") - strlen("/lib") - strlen(".so"));

        string libprebuild = prebuild_shared;

        libprebuild.replace(libprebuild.find(chijilyb_tag_libname, 0), chijilyb_tag_libname_len, libname);
        libprebuild.replace(libprebuild.find(chijilyb_tag_libpath, 0), chijilyb_tag_libpath_len, libpath);

        out.write(libprebuild.c_str(), libprebuild.size());
    }
}

void produce_cpp(ofstream& out, const string& include_path, const string& static_lib_path,
                                const string& shared_lib_path, const string& cpp_path)
{
    string whole = R"==(

include \$(CLEAR_VARS)
LOCAL_MODULE     			:= chijilyb_tag_modulename

)==";

// include
{
    string incpath(R"==(LOCAL_C_INCLUDES 		    := \$(LOCAL_PATH))==");
    ifstream in(include_path.c_str(), ios_base::binary);
    string str;

    while(getline(in, str))
    {
        incpath += string(R"==( \\
							   \$(LOCAL_PATH))==") + str.substr(strlen("."));

    }

    whole += incpath;
}

    whole += R"==(

LOCAL_LDLIBS     			:= -llog

)==";

// static library
{
    string library(R"==(LOCAL_STATIC_LIBRARIES 		:= )==");
    ifstream in(static_lib_path.c_str(), ios_base::binary);
    string str;

    while(getline(in, str))
    {
        library += str.substr(str.rfind("/lib") + strlen("/"),
                              str.size()-str.rfind("/lib")- strlen("/") - strlen(".a"));
        library += R"==( \\
							   )==";
    }

    library = library.substr(0, library.find_last_of("\\\") - strlen(" "));

    whole += library;
}
    whole += "\n\n";

// shared library
{
    string library(R"==(LOCAL_SHARED_LIBRARIES 		:= )==");
    ifstream in(shared_lib_path.c_str(), ios_base::binary);
    string str;

    while(getline(in, str))
    {
        library += str.substr(str.rfind("/lib") + strlen("/lib"),
                              str.size()-str.rfind("/lib") - strlen("/lib") - strlen(".so"));
        library += R"==( \\
							   )==";
    }

    library = library.substr(0, library.find_last_of("\\\") - strlen(" "));

    whole += library;
}
    whole += R"==(

LOCAL_CFLAGS 				:= -fPIC

)==";

// cpp
{
    string cppname(R"==(LOCAL_SRC_FILES 			:= )==");
    ifstream in(cpp_path.c_str(), ios_base::binary);
    string str;

    while(getline(in, str))
    {
        cppname += str.substr(strlen("./"), str.size() - strlen("./"));
        cppname += R"==( \\
							   )==";
    }

    cppname = cppname.substr(0, cppname.find_last_of("\\\") - strlen(" "));

    whole += cppname;
}
    whole += R"==(

include \$(BUILD_SHARED_LIBRARY)
################################################################)==";

    out.write(whole.c_str(), whole.size());
}

void produce_android_mk(void)
{
    ofstream out("Android.mk", ios_base::binary);

    string str = gettime();
	out.write(str.c_str(), str.size());

    static const string static_lib_path("a.txt");
    static const string shared_lib_path("so.txt");
    static const string include_path   ("h.txt");
    static const string cpp_path       ("cpp.txt");

    produce_prebuild_static_lib(out, static_lib_path);
    produce_prebuild_shared_lib(out, shared_lib_path);
    produce_cpp(out, include_path, static_lib_path, shared_lib_path, cpp_path);
}

int main(int argc, char**)
{
    produce_application_mk();
    produce_android_mk();

    return 0;
}

EOF

./a.out

rm a.txt
rm so.txt
rm h.txt
rm cpp.txt
rm a.out
