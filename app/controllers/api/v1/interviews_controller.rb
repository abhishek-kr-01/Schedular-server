require 'sendgrid-ruby'
include SendGrid

module Api
    module V1
        class InterviewsController < ApplicationController
                  
            def index
                interviews = Interview.order(date: :asc, start_time: :asc);
                list = []
                interviews.each do |inter|
                    list << inter.attributes.merge({"participants" => inter.participants})
                end

                render json: {status: 'SUCCESS', message:'Loaded Interviews', data: list},status: :ok
            end

            def show 
                interview = Interview.find(params[:id])
                participants = interview.participants
                interviewers = []
                candidates = []
                participants.each do |person|
                    if person.is_candidate
                        candidates << person
                    else
                        interviewers << person
                    end
                end
                
                render json: {status: 'SUCCESS', message:'Loaded Interview', data: interview.attributes.merge({"interviewers" => interviewers, "candidates" => candidates})},status: :ok
            end

            def create
                interview = Interview.new(interview_params)

                interviewers = params[:interviewers]
                candidates = params[:candidates]

                total_participants = []
                for pid in interviewers
                    person = Participant.find_by(:id => pid)

                    total_participants << person
                end
                for pid in candidates
                    person = Participant.find_by(:id => pid)

                    total_participants << person
                end


                if not overlaps(total_participants, interview)
                    if interview.save

                        
                        # puts mail_content
                        for one in total_participants
                            interview.participants << one

                            
                            puts one.email
                            puts one.name
                            mail_content = "Hey "+one.name+"!\n\nYou have an interview scheduled.\n\nDescription : "+interview.description+"\nDate :"+interview.date.strftime("%d/%m/%Y")+"\nStart time: "+interview.start_time.strftime("%H:%M")+"\nEnd time :"+interview.end_time.strftime("%H:%M")
                            #sendgrid mail func
                            from = SendGrid::Email.new(email: "interviewtesterib@gmail.com")
                            to = SendGrid::Email.new(email: one.email)
                            subject = interview.name
                            content = SendGrid::Content.new(type: 'text/plain', value: mail_content)
                            mail = SendGrid::Mail.new(from, subject, to, content)

                            sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'])
                            response = sg.client.mail._('send').post(request_body: mail.to_json)
                            puts response.status_code
                            puts response.body
                            puts response.headers
                            #
                        end

                        
                        render json: {status: 'SUCCESS', message:'Created Interview', data: interview},status: :ok
                    else
                        render json: {status: 'ERROR', message: interview.errors},status: :bad_request
                    end
                else
                    render json: {status: 'ERROR', message:'Overlap with existing interview detected.'},status: :method_not_allowed
                end
            end

            def update
                interview = Interview.find(params[:id])

                interviewers = params[:interviewers]
                candidates = params[:candidates]

                total_participants = []
                for pid in interviewers
                    person = Participant.find_by(:id => pid)

                    total_participants << person
                end
                for pid in candidates
                    person = Participant.find_by(:id => pid)

                    total_participants << person
                end
                
                if not overlaps(total_participants, interview)
                    if interview.update_attributes(interview_params)

                        interview.participants.clear

                        for one in total_participants
                            interview.participants << one

                            # NotificationMailer.new_interview(one,interview,false).deliver_now
                        end
                        render json: {status: 'SUCCESS', message:'Updated Interview', data: interview},status: :ok
                    else
                        render json: {status: 'ERROR', message: interview.errors},status: :bad_request
                    end
                else
                    render json: {status: 'ERROR', message:'Overlap with existing interview detected.'},status: :method_not_allowed
                end
            end 

            def destroy
                interview = Interview.find(params[:id])

                if interview.destroy
                    render json: {status: 'SUCCESS', message:'Deleted Interview'},status: :ok
                else
                    render json: {status: 'ERROR', message: interview.errors},status: :bad_request
                end
            end

            private

            def interview_params
                params.require(:interview).permit(:name, :description, :date, :start_time, :end_time)
            end

            def overlaps (participants, interview)
                given_id = interview.id
                given_date = interview.date
                start = interview.start_time
                finish = interview.end_time
                participants.each do |person|
                    person_interviews = person.interviews

                    person_interviews.each do |inter|
                        if inter.id!=given_id and given_date==inter.date and !((start >= inter.end_time) or (finish <= inter.start_time))
                            return true
                        end
                    end
                end

                return false
            end
        end
    end
end